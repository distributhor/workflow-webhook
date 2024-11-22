#!/bin/bash

# Enable the printing of trace messages
set -o errtrace
trap 'echo "Error occurred on line $BASH_LINENO"; exit 1' ERR

# Github Inputs/Envs Fix: Iterate over environment variables starting with INPUT_ and export them as lowercase variables without input_ prefix.
for var in "${!INPUT_@}"; do
  # Remove the INPUT_ prefix
  name="${var#INPUT_}"

  # Convert name to lowercase
  name_lower="${name,,}"

  # Access the value of the environment variable
  value="${!var}"

  # Check if the variable is already exported
  if [[ -z "${!name_lower+x}" ]]; then
    if [ "$fine" = true ]; then
      # Export the variable if it's not already present
      echo "INFO: Converting INPUT_${name}=$value to $name_lower=$value"
    fi
    export "$name_lower"="$value"
  else
    echo "WARN: Variable already exists with $(env | grep "${name_lower}="), not exporting."
  fi
done

# The following manual variable conversions are still necessary for backwards compatibility with previous versions.
# This is now considered deprecated, and for v4 of this webhook it will be removed.
if [ -n "$WEBHOOK_AUTH" ]; then
    webhook_auth=$WEBHOOK_AUTH
fi

if [ -n "$WEBHOOK_AUTH_TYPE" ]; then
    webhook_auth_type=$WEBHOOK_AUTH_TYPE
fi

if [ -n "$WEBHOOK_SECRET" ]; then
    webhook_secret=$WEBHOOK_SECRET
fi

if [ -n "$WEBHOOK_TYPE" ]; then
    webhook_type=$WEBHOOK_TYPE
fi

if [ -n "$WEBHOOK_URL" ]; then
    webhook_url=$WEBHOOK_URL
fi

if [ -n "$SILENT" ]; then
    silent=$SILENT
fi

if [ -n "$VERBOSE" ]; then
    verbose=$VERBOSE
fi

if [ -n "$VERIFY_SSL" ]; then
    verify_ssl=$VERIFY_SSL
fi

if [ -n "$TIMEOUT" ]; then
    timeout=$TIMEOUT
fi

if [ -n "$MAX_TIME" ]; then
    max_time=$MAX_TIME
fi

if [ -n "$CURL_OPTS" ]; then
    curl_opts=$CURL_OPTS
fi

if [ -n "$EVENT_NAME" ]; then
    event_name=$EVENT_NAME
fi

if [ -n "$DATA" ]; then
    data=$DATA
fi

urlencode() {
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf '%s' "$c" | xxd -p -c1 |
                   while read c; do printf '%%%s' "$c"; done ;;
        esac
    done
}

urldecode() {
    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}

set -e

if [ -z "$webhook_url" ]; then
    echo "No webhook_url configured"
    exit 1
fi

if [ -z "$webhook_secret" ]; then
    webhook_secret=$webhook_url
fi

#
# This method does not require additional package installation (of util-linux) 
# on docker image, resulting in a slightly smaller image file
#
# REQUEST_ID=$(cat /dev/urandom | tr -dc '0-9a-f' | fold -w 32 | head -n 1)

#
# This method is cleaner, but requires util-linux to be installed on Alpine image,
# resuling in a slightly larger image file
# 
REQUEST_ID=$(uuidgen)

if [ "$silent" != true ]; then
    echo "Webhook Request ID: $REQUEST_ID"
fi

if [ -n "$event_name" ]; then
    EVENT_NAME=$event_name
else
    EVENT_NAME=$GITHUB_EVENT_NAME
fi

if [ -n "$webhook_type" ] && [ "$webhook_type" == "form-urlencoded" ]; then

    EVENT=`urlencode "$EVENT_NAME"`
    REPOSITORY=`urlencode "$GITHUB_REPOSITORY"`
    COMMIT=`urlencode "$GITHUB_SHA"`
    REF=`urlencode "$GITHUB_REF"`
    HEAD=`urlencode "$GITHUB_HEAD_REF"`
    WORKFLOW=`urlencode "$GITHUB_WORKFLOW"`

    CONTENT_TYPE="application/x-www-form-urlencoded"
    WEBHOOK_DATA="event=$EVENT&repository=$REPOSITORY&commit=$COMMIT&ref=$REF&head=$HEAD&workflow=$WORKFLOW&requestID=$REQUEST_ID"

    if [ -n "$data" ]; then
        WEBHOOK_DATA="${WEBHOOK_DATA}&${data}"
    fi

else

    CONTENT_TYPE="application/json"

    if [ -n "$webhook_type" ] && [ "$webhook_type" == "json-extended" ]; then
        RAW_FILE_DATA=`cat $GITHUB_EVENT_PATH`
        echo "DEBUG JQ: A"
        WEBHOOK_DATA=$(echo -n "$RAW_FILE_DATA" | jq -c '.')
    else
        WEBHOOK_DATA=$(jo event="$EVENT_NAME" repository="$GITHUB_REPOSITORY" commit="$GITHUB_SHA" ref="$GITHUB_REF" head="$GITHUB_HEAD_REF" workflow="$GITHUB_WORKFLOW")
    fi
    
    if [ -n "$data" ]; then
        echo "DEBUG JQ: B"
        CUSTOM_JSON_DATA=$(echo -n "$data" | jq -c '.')
        echo "DEBUG JQ: C"
        WEBHOOK_DATA=$(jq -s '.[0] * .[1]' <(echo $WEBHOOK_DATA) <(jo requestID="$REQUEST_ID" data="$CUSTOM_JSON_DATA"))
    else
        echo "DEBUG JQ: D"
        WEBHOOK_DATA=$(jq -s '.[0] * .[1]' <(echo $WEBHOOK_DATA) <(jo requestID="$REQUEST_ID"))
    fi

fi

WEBHOOK_SIGNATURE=$(echo -n "$WEBHOOK_DATA" | openssl dgst -sha1 -hmac "$webhook_secret" -binary | xxd -p)
WEBHOOK_SIGNATURE_256=$(echo -n "$WEBHOOK_DATA" | openssl dgst -sha256 -hmac "$webhook_secret" -binary | xxd -p |tr -d '\n')
WEBHOOK_ENDPOINT=$webhook_url

if [ -n "$webhook_auth_type" ] && [ "$webhook_auth_type" == "bearer" ]; then
    auth_type="bearer"
elif [ -n "$webhook_auth_type" ] && [ "$webhook_auth_type" == "header" ]; then
    auth_type="header"
else
    auth_type="basic"
fi

if [ -n "$webhook_auth" ] && [ "$auth_type" == "basic" ]; then
    WEBHOOK_ENDPOINT="-u $webhook_auth $webhook_url"
fi

options="--http1.1 --fail-with-body"

if [ "$verbose" = true ]; then
    options="$options -v"
    options="$options -sS"
elif [ "$silent" = true ]; then
    options="$options -s"
else
    # The -s disables the progress meter, as well as error messages. 
    # We want Curl to report errors, which we reenable with -S
    options="$options -sS"
fi

if [ "$verify_ssl" = false ]; then
    options="$options -k"
fi

if [ -n "$timeout" ]; then
    options="$options --connect-timeout $timeout"
fi

if [ -n "$max_time" ]; then
    options="$options --max-time $max_time"
fi

if [ -n "$curl_opts" ]; then
    options="$options $curl_opts"
fi

echo "verify_ssl = $verify_ssl"
echo "silent = $silent"
echo "verbose = $verbose"
echo "curl_connection_close = $curl_connection_close"
echo "connection = $connection"

if [ "$curl_connection_close" = true ]; then
    echo "A"
fi

if [ "$curl_connection_close" == true ]; then
    echo "B"
fi

if [ "$curl_connection_close" == 'true' ]; then
    echo "C"
fi

if [ "$connection" = true ]; then
    echo "X"
fi

if [ "$connection" == true ]; then
    echo "Y"
fi

if [ "$connection" == 'true' ]; then
    echo "Z"
fi

if [ "$connection" = false ]; then
    echo "XX"
fi

if [ "$connection" == false ]; then
    echo "YY"
fi

if [ "$connection" == 'false' ]; then
    echo "ZZ"
fi

if [ "$verbose" = true ]; then
    echo "curl $options \\"
    echo "-H 'Content-Type: $CONTENT_TYPE' \\"
    echo "-H 'User-Agent: GitHub-Hookshot/$REQUEST_ID' \\"
    echo "-H 'X-Hub-Signature: sha1=$WEBHOOK_SIGNATURE' \\"
    echo "-H 'X-Hub-Signature-256: sha256=$WEBHOOK_SIGNATURE_256' \\"
    echo "-H 'X-GitHub-Delivery: $REQUEST_ID' \\"
    echo "-H 'X-GitHub-Event: $EVENT_NAME' \\"

    if [ "$curl_connection_close" = true ]; then
        echo "-H 'Connection: close' \\"
    fi

    echo "--data '$WEBHOOK_DATA'"
fi

set +e

# auth_header=''

if [ -n "$webhook_auth" ] && [ "$auth_type" == "bearer" ]; then
    # auth_header="-H \"Authorization: Bearer $webhook_auth\""
    if [ "$curl_connection_close" = true ]; then
        response=$(curl $options \
        -H "Authorization: Bearer $webhook_auth" \
        -H "Content-Type: $CONTENT_TYPE" \
        -H "User-Agent: GitHub-Hookshot/$REQUEST_ID" \
        -H "X-Hub-Signature: sha1=$WEBHOOK_SIGNATURE" \
        -H "X-Hub-Signature-256: sha256=$WEBHOOK_SIGNATURE_256" \
        -H "X-GitHub-Delivery: $REQUEST_ID" \
        -H "X-GitHub-Event: $EVENT_NAME" \
        -H "Connection: close" \
        --data "$WEBHOOK_DATA" $WEBHOOK_ENDPOINT)
    else
        response=$(curl $options \
        -H "Authorization: Bearer $webhook_auth" \
        -H "Content-Type: $CONTENT_TYPE" \
        -H "User-Agent: GitHub-Hookshot/$REQUEST_ID" \
        -H "X-Hub-Signature: sha1=$WEBHOOK_SIGNATURE" \
        -H "X-Hub-Signature-256: sha256=$WEBHOOK_SIGNATURE_256" \
        -H "X-GitHub-Delivery: $REQUEST_ID" \
        -H "X-GitHub-Event: $EVENT_NAME" \
        --data "$WEBHOOK_DATA" $WEBHOOK_ENDPOINT)
    fi
elif [ -n "$webhook_auth" ] && [ "$auth_type" == "header" ]; then
    header_name=`[[ $webhook_auth =~ ([^:]*) ]] && echo "${BASH_REMATCH[1]}"`
    header_value=`[[ $webhook_auth =~ :(.*) ]] && echo "${BASH_REMATCH[1]}"`
    if [ -z "$header_value" ]; then
        # if the webhook_auth value contains no colon, then it is a configuration error
        # we should not handle such cases, but in instead of throwing an error, we try
        # and consider a potential fail-safe for user error, and resort to setting the
        # entire value as an Authorization token - the attempt at trying to resolve what 
        # the author meant may or may not be a better approach than just letting it error?
        # auth_header="-H \"Authorization: $webhook_auth\""
        if [ "$curl_connection_close" = true ]; then
            response=$(curl $options \
            -H "Authorization: $webhook_auth" \
            -H "Content-Type: $CONTENT_TYPE" \
            -H "User-Agent: GitHub-Hookshot/$REQUEST_ID" \
            -H "X-Hub-Signature: sha1=$WEBHOOK_SIGNATURE" \
            -H "X-Hub-Signature-256: sha256=$WEBHOOK_SIGNATURE_256" \
            -H "X-GitHub-Delivery: $REQUEST_ID" \
            -H "X-GitHub-Event: $EVENT_NAME" \
            -H "Connection: close" \
            --data "$WEBHOOK_DATA" $WEBHOOK_ENDPOINT)
        else
            response=$(curl $options \
            -H "Authorization: $webhook_auth" \
            -H "Content-Type: $CONTENT_TYPE" \
            -H "User-Agent: GitHub-Hookshot/$REQUEST_ID" \
            -H "X-Hub-Signature: sha1=$WEBHOOK_SIGNATURE" \
            -H "X-Hub-Signature-256: sha256=$WEBHOOK_SIGNATURE_256" \
            -H "X-GitHub-Delivery: $REQUEST_ID" \
            -H "X-GitHub-Event: $EVENT_NAME" \
            --data "$WEBHOOK_DATA" $WEBHOOK_ENDPOINT)
        fi
    else
        # auth_header="-H \"$header_name: $header_value\""
        if [ "$curl_connection_close" = true ]; then
            response=$(curl $options \
            -H "$header_name: $header_value" \
            -H "Content-Type: $CONTENT_TYPE" \
            -H "User-Agent: GitHub-Hookshot/$REQUEST_ID" \
            -H "X-Hub-Signature: sha1=$WEBHOOK_SIGNATURE" \
            -H "X-Hub-Signature-256: sha256=$WEBHOOK_SIGNATURE_256" \
            -H "X-GitHub-Delivery: $REQUEST_ID" \
            -H "X-GitHub-Event: $EVENT_NAME" \
            -H "Connection: close" \
            --data "$WEBHOOK_DATA" $WEBHOOK_ENDPOINT)
        else
            response=$(curl $options \
            -H "$header_name: $header_value" \
            -H "Content-Type: $CONTENT_TYPE" \
            -H "User-Agent: GitHub-Hookshot/$REQUEST_ID" \
            -H "X-Hub-Signature: sha1=$WEBHOOK_SIGNATURE" \
            -H "X-Hub-Signature-256: sha256=$WEBHOOK_SIGNATURE_256" \
            -H "X-GitHub-Delivery: $REQUEST_ID" \
            -H "X-GitHub-Event: $EVENT_NAME" \
            --data "$WEBHOOK_DATA" $WEBHOOK_ENDPOINT)
        fi
    fi
else
    if [ "$curl_connection_close" = true ]; then
        response=$(curl $options \
        -H "Content-Type: $CONTENT_TYPE" \
        -H "User-Agent: GitHub-Hookshot/$REQUEST_ID" \
        -H "X-Hub-Signature: sha1=$WEBHOOK_SIGNATURE" \
        -H "X-Hub-Signature-256: sha256=$WEBHOOK_SIGNATURE_256" \
        -H "X-GitHub-Delivery: $REQUEST_ID" \
        -H "X-GitHub-Event: $EVENT_NAME" \
        -H "Connection: close" \
        --data "$WEBHOOK_DATA" $WEBHOOK_ENDPOINT)
    else
        response=$(curl $options \
        -H "Content-Type: $CONTENT_TYPE" \
        -H "User-Agent: GitHub-Hookshot/$REQUEST_ID" \
        -H "X-Hub-Signature: sha1=$WEBHOOK_SIGNATURE" \
        -H "X-Hub-Signature-256: sha256=$WEBHOOK_SIGNATURE_256" \
        -H "X-GitHub-Delivery: $REQUEST_ID" \
        -H "X-GitHub-Event: $EVENT_NAME" \
        --data "$WEBHOOK_DATA" $WEBHOOK_ENDPOINT)
    fi
fi

# headers="-H \"Content-Type: $CONTENT_TYPE\""
# headers="$headers -H \"User-Agent: GitHub-Hookshot/$REQUEST_ID\""
# headers="$headers -H \"X-Hub-Signature: sha1=$WEBHOOK_SIGNATURE\""
# headers="$headers -H \"X-Hub-Signature-256: sha256=$WEBHOOK_SIGNATURE_256\""
# headers="$headers -H \"X-GitHub-Delivery: $REQUEST_ID\""
# headers="$headers -H \"X-GitHub-Event: $EVENT_NAME\""

# if [ "$curl_connection_close" = true ]; then
#     headers="$headers -H \"Connection: close\""
# fi

# if [ "$verbose" = true ]; then
#     echo "curl $options \\"
    
#     if [ -n "$auth_header" ]; then
#         echo "$auth_header $headers \\"
#     else
#         echo "$headers \\"
#     fi
    
#     echo "--data '$WEBHOOK_DATA'"

#     # some console logs will remove the log statement if its a URL
#     # so we need to remove the protocol if we want to display this
#     noproto_webhook_url=`echo $WEBHOOK_ENDPOINT | sed -E 's/^\s*.*:\/\///g'`
#     echo "WEBHOOK_ENDPOINT: $noproto_webhook_url"
# fi

# set +e

# response=$(curl $options $auth_header $headers --data "$WEBHOOK_DATA" $WEBHOOK_ENDPOINT)

CURL_STATUS=$?

# echo "response-body=$response" >> $GITHUB_OUTPUT
echo "response-body<<$REQUEST_ID" >> $GITHUB_OUTPUT
echo "$response" >> $GITHUB_OUTPUT
echo "$REQUEST_ID" >> $GITHUB_OUTPUT

if [ "$verbose" = true ]; then
    echo "Webhook Response [$CURL_STATUS]:"
    echo "${response}"
fi

exit $CURL_STATUS
