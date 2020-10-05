#!/bin/bash

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
    echo "No webhook_secret configured"
    exit 1
fi

if [ -n "$webhook_type" ] && [ "$webhook_type" == "form-urlencoded" ]; then
    
    event=`urlencode "$GITHUB_EVENT_NAME"`
    repository=`urlencode "$GITHUB_REPOSITORY"`
    commit=`urlencode "$GITHUB_SHA"`
    ref=`urlencode "$GITHUB_REF"`
    head=`urlencode "$GITHUB_HEAD_REF"`
    workflow=`urlencode "$GITHUB_WORKFLOW"`

    CONTENT_TYPE="application/x-www-form-urlencoded"
    FORM_DATA="event=$event&repository=$repository&commit=$commit&ref=$ref&head=$head&workflow=$workflow"
    
    if [ -n "$data" ]; then
        WEBHOOK_DATA="$FORM_DATA&$data"
    else
        WEBHOOK_DATA="$FORM_DATA"
    fi

else

    CONTENT_TYPE="application/json"
    JSON_DATA="\"event\":\"$GITHUB_EVENT_NAME\",\"repository\":\"$GITHUB_REPOSITORY\",\"commit\":\"$GITHUB_SHA\",\"ref\":\"$GITHUB_REF\",\"head\":\"$GITHUB_HEAD_REF\",\"workflow\":\"$GITHUB_WORKFLOW\""
    
    if [ -n "$data" ]; then
        COMPACT_JSON=$(echo -n "$data" | jq -c '')
        WEBHOOK_DATA="{$JSON_DATA,\"data\":$COMPACT_JSON}"
    else
        WEBHOOK_DATA="{$JSON_DATA}"
    fi

fi

WEBHOOK_SIGNATURE=$(echo -n "$WEBHOOK_DATA" | openssl sha1 -hmac "$webhook_secret" -binary | xxd -p)
WEBHOOK_ENDPOINT=$webhook_url

if [ -n "$webhook_auth" ]; then
    WEBHOOK_ENDPOINT="-u $webhook_auth $webhook_url"
fi

echo "Content Type: $CONTENT_TYPE"

curl -k -v --fail \
    -H "Content-Type: $CONTENT_TYPE" \
    -H "User-Agent: User-Agent: GitHub-Hookshot/760256b" \
    -H "X-Hub-Signature: sha1=$WEBHOOK_SIGNATURE" \
    -H "X-GitHub-Delivery: $GITHUB_RUN_NUMBER" \
    -H "X-GitHub-Event: $GITHUB_EVENT_NAME" \
    --data "$WEBHOOK_DATA" $WEBHOOK_ENDPOINT

# wget -q --server-response --timeout=2000 -O - \
#    --header="Content-Type: application/json" \
#    --header="User-Agent: User-Agent: GitHub-Hookshot/760256b" \
#    --header="X-Hub-Signature: sha1=$WEBHOOK_SIGNATURE" \
#    --header="X-GitHub-Delivery: $GITHUB_RUN_NUMBER" \
#    --header="X-GitHub-Event: $GITHUB_EVENT_NAME" \
#    --post-data "$WEBHOOK_DATA" $webhook_url
#    # --http-user user --http-password