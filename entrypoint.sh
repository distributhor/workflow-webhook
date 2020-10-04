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

DATA_JSON="\"repository\":\"$GITHUB_REPOSITORY\",\"ref\":\"$GITHUB_HEAD_REF\",\"commit\":\"$GITHUB_SHA\",\"trigger\":\"$GITHUB_EVENT_NAME\",\"workflow\":\"$GITHUB_WORKFLOW\""

if [ -n "$data" ]; then
    COMPACT_JSON=$(echo -n "$data" | jq -c '')
    WEBHOOK_DATA="{$DATA_JSON,\"data\":$COMPACT_JSON}"
    # WEBHOOK_DATA=$(jq -c . $GITHUB_EVENT_PATH)
else
    WEBHOOK_DATA="{$DATA_JSON}"
fi

WEBHOOK_SIGNATURE=$(echo -n "$WEBHOOK_DATA" | openssl sha1 -hmac "$webhook_secret" -binary | xxd -p)
# WEBHOOK_SIGNATURE=$(cat "$GITHUB_EVENT_PATH" | openssl sha1 -hmac "$webhook_secret" -binary | xxd -p)

WEBHOOK_ENDPOINT=$webhook_url
if [ -n "$webhook_auth" ]; then
    WEBHOOK_ENDPOINT="-u $webhook_auth $webhook_url"
fi

# Note:
#   "curl --trace-ascii /dev/stdout" is an alternative to "curl -v", and includes 
#   the posted data in the output. However, it can't do so for multipart/form-data

curl -k -v \
    -H "Content-Type: application/json" \
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