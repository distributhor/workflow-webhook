#!/bin/bash

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
    CONTENT_TYPE="application/x-www-form-urlencoded"
else
    CONTENT_TYPE="application/json"
fi

if [ "$CONTENT_TYPE" == "application/x-www-form-urlencoded" ]; then
    
    FORM_DATA="repository=$GITHUB_REPOSITORY&ref=$GITHUB_REF&head=$GITHUB_HEAD_REF&commit=$GITHUB_SHA&event=$GITHUB_EVENT_NAME&workflow=$GITHUB_WORKFLOW"

    if [ -n "$data" ]; then
        WEBHOOK_DATA="$FORM_DATA&$data"
    else
        WEBHOOK_DATA="$FORM_DATA"
    fi

else

    DATA_JSON="\"repository\":\"$GITHUB_REPOSITORY\",\"ref\":\"$GITHUB_REF\",\"head\":\"$GITHUB_HEAD_REF\",\"commit\":\"$GITHUB_SHA\",\"event\":\"$GITHUB_EVENT_NAME\",\"workflow\":\"$GITHUB_WORKFLOW\""

    if [ -n "$data" ]; then
        COMPACT_JSON=$(echo -n "$data" | jq -c '')
        WEBHOOK_DATA="{$DATA_JSON,\"data\":$COMPACT_JSON}"
    else
        WEBHOOK_DATA="{$DATA_JSON}"
    fi

fi

WEBHOOK_SIGNATURE=$(echo -n "$WEBHOOK_DATA" | openssl sha1 -hmac "$webhook_secret" -binary | xxd -p)

WEBHOOK_ENDPOINT=$webhook_url

if [ -n "$webhook_auth" ]; then
    WEBHOOK_ENDPOINT="-u $webhook_auth $webhook_url"
fi

# Note:
#   "curl --trace-ascii /dev/stdout" is an alternative to "curl -v", and includes 
#   the posted data in the output. However, it can't do so for multipart/form-data 

curl -k -v \
    -H "Content-Type: $CONTENT_TYPE" \
    -H "User-Agent: User-Agent: GitHub-Hookshot/760256b" \
    -H "X-Hub-Signature: sha1=$WEBHOOK_SIGNATURE" \
    -H "X-GitHub-Delivery: $GITHUB_RUN_NUMBER" \
    -H "X-GitHub-Event: $GITHUB_EVENT_NAME" \
    --data "$WEBHOOK_DATA" $WEBHOOK_ENDPOINT
    # -D - $WEBHOOK_ENDPOINT --data-urlencode @"$GITHUB_EVENT_PATH"

# wget -q --server-response --timeout=2000 -O - \
#    --header="Content-Type: application/json" \
#    --header="User-Agent: User-Agent: GitHub-Hookshot/760256b" \
#    --header="X-Hub-Signature: sha1=$WEBHOOK_SIGNATURE" \
#    --header="X-GitHub-Delivery: $GITHUB_RUN_NUMBER" \
#    --header="X-GitHub-Event: $GITHUB_EVENT_NAME" \
#    --post-data "$WEBHOOK_DATA" $webhook_url
#    # --http-user user --http-password