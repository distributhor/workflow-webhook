FROM ubuntu:bionic

LABEL "name"="bash"
LABEL "repository"="https://github.com/distributhor/workflow-webhook"
LABEL "version"="1.0.0"

LABEL com.github.actions.name="Workflow Webhook"
LABEL com.github.actions.description="An action that will call a webhook from your Github workflow"
LABEL com.github.actions.icon="upload-cloud"
LABEL com.github.actions.color="gray-dark"

RUN apt-get update && apt-get install -y curl openssl xxd jq

COPY LICENSE README.md /
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
