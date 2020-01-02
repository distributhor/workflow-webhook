# Workflow Webhook Action

[![GitHub Release][ico-release]][link-github-release]
[![License][ico-license]](LICENSE)

A github workflow action to call a remote webhook endpoint with a text/csv 
or json payload, and support for BASIC authentication. A hash signature is
passed with each request, derived from the payload and a configurable 
secret token. The hash signature is identical to that which a regular Github
webhook would generate, and sent in a header field named `X-Hub-Signature`.
Therefore any existing Github webhook signature validation will continue to 
work. For more information on how to valiate the signature, see 
<https://developer.github.com/webhooks/securing>.

By default, the values of the following workflow environment variables are
sent in the payload: `GITHUB_REPOSITORY`, `GITHUB_REF`, `GITHUB_SHA`, 
`GITHUB_EVENT_NAME` and `GITHUB_WORKFLOW`. For more information on the
information contained in these variables, see <https://help.github.com/en/actions/automating-your-workflow-with-github-actions/using-environment-variables>. 
Any additional data can be added to the payload as well.

## Usage

Send the default JSON payload to a webhook:

```yml
    - name: Invoke deployment hook
      uses: distributhor/workflow-webhook@master
      env:
        webhook_url: ${{ secrets.WEBHOOK_URL }}
        webhook_secret: ${{ secrets.WEBHOOK_SECRET }}
```

Will deliver a payload with the following properties:

```json
{
    "repository": "owner/project",
    "ref": "refs/heads/master",
    "commit": "a636b6f0861bbee98039bf3df66ee13d8fbc9c74",
    "event": "push",
    "workflow": "Build and deploy"
}
```

Add additional JSON data to the payload:

```yml
    - name: Invoke deployment hook
      uses: distributhor/workflow-webhook@master
      env:
        webhook_url: ${{ secrets.WEBHOOK_URL }}
        webhook_secret: ${{ secrets.WEBHOOK_SECRET }}
        data: '{ "weapon": "hammer", "drink" : "beer" }'
```

The additional data will become available on a 'data' property,
and now look like:

```json
{
    "repository": "owner/project",
    "ref": "refs/heads/master",
    "commit": "a636b6f0861bbee98039bf3df66ee13d8fbc9c74",
    "event": "push",
    "workflow": "Build and deploy",
    "data": {
        "weapon": "hammer",
        "drink": "beer"
    }
}
```

Send a CSV payload instead:

```yml
    - name: Invoke deployment hook
      uses: distributhor/workflow-webhook@master
      env:
        webhook_url: ${{ secrets.WEBHOOK_URL }}
        webhook_secret: ${{ secrets.WEBHOOK_SECRET }}
        data: '"hammer";"beer"'
        data_type: 'csv'
```

Will deliver:

```csv
"owner/project";"refs/heads/master";"a636b6f0861bbee98039bf3df66ee13d8fbc9c74";"push";"Build and deploy";"hammer";"beer"
```

No header entry is provded for the CSV, the first 5 fields will always be
`repository;ref;commit;event;workflow`


### Arguments

* ```yml 
  webhook_url: "..."
  ```

* ```yml 
  webhook_secret: "..."
  ```

* ```yml 
  data: "..."
  ```

* ```yml 
  data_type: "..."
  ```

## Validation

- JSON: Invalid numeric literal
- CSV: quote the fields


## License

The MIT License (MIT). Please see [License File](LICENSE) for more information.

[ico-release]: https://img.shields.io/github/tag/distributhor/webhook-action.svg
[ico-license]: https://img.shields.io/badge/license-MIT-brightgreen.svg
[link-github-release]: https://github.com/distributhor/workflow-webhook/releases