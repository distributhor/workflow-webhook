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

HEAD_REF="${head_ref:-$GITHUB_HEAD_REF}"
COMMIT_SHA="${commit_sha:-$GITHUB_SHA}"
EVENT_NAME="${event_name:-$GITHUB_EVENT_NAME}"

DATA_JSON="\"repository\":\"$GITHUB_REPOSITORY\",\"ref\":\"$HEAD_REF\",\"commit\":\"$COMMIT_SHA\",\"trigger\":\"$EVENT_NAME\",\"workflow\":\"$GITHUB_WORKFLOW\""

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

result=$(curl -q --max-time 1500 -o - --no-buffer -X POST \
    -H "content-type: application/json" \
    -H "User-Agent: User-Agent: GitHub-Hookshot/760256b" \
    -H "X-Hub-Signature: sha1=$WEBHOOK_SIGNATURE" \
    -H "X-GitHub-Delivery: $GITHUB_RUN_NUMBER" \
    -H "X-GitHub-Event: $EVENT_NAME" \
    --data "$WEBHOOK_DATA" $webhook_url
)

echo "Result: $result"
echo "::set-output name=result::$result"
