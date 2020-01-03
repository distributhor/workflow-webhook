# Workflow Webhook Action

[![GitHub Release][ico-release]][link-github-release]
[![License][ico-license]](LICENSE)

A Github workflow action to call (POST) a remote webhook endpoint with a text/csv 
or json payload, and support for BASIC authentication. A hash signature is passed 
with each request, derived from the payload and a configurable secret token. The 
hash signature is identical to that which a regular Github webhook would generate, 
and sent in a header field named `X-Hub-Signature`. Therefore any existing Github 
webhook signature validation will continue to work. For more information on how to 
valiate the signature, see <https://developer.github.com/webhooks/securing>.

By default, the values of the following workflow environment variables are sent in 
the payload: `GITHUB_REPOSITORY`, `GITHUB_REF`, `GITHUB_SHA`, `GITHUB_EVENT_NAME` 
and `GITHUB_WORKFLOW`. For more information on what is contained in these variables, 
see <https://help.github.com/en/actions/automating-your-workflow-with-github-actions/using-environment-variables>. 
Additional data can be added to the payload as well.


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

Add additional data to the payload:

```yml
    - name: Invoke deployment hook
      uses: distributhor/workflow-webhook@master
      env:
        webhook_url: ${{ secrets.WEBHOOK_URL }}
        webhook_secret: ${{ secrets.WEBHOOK_SECRET }}
        data: '{ "weapon": "hammer", "drink" : "beer" }'
```

The additional information will become available on a 'data' property,
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

Will set the `content-type` header to `text/csv` and deliver:

```csv
"owner/project";"refs/heads/master";"a636b6f0861bbee98039bf3df66ee13d8fbc9c74";"push";"Build and deploy";"hammer";"beer"
```


### Arguments

```yml 
  webhook_url: "https://your.webhook"
```

**Required**. The HTTP URI of the webhook endpoint to invoke. The endpoint must accept 
an HTTP POST request.
\

```yml 
  webhook_secret: "Y0uR5ecr3t"
```

**Required**. The secret with which to generate the signature hash.

```yml 
  data_type: "json | csv"
```

The default data type is json. The argument is only required if you wish to send CSV. 
Otherwise it's optional.

```yml 
  data: '{ "additional": "properties" }'
```

Any additional data to include in the payload. The argument is optional if the default 
fields are sufficient and you wish to provide no further information.

For JSON data, it will be available on a property named `data`. The additional data 
will be run through a json validator, and any invalid configuration will break. For 
example, if you quote json properties and values with single quotes instead of double 
quotes you will see the following (somewhat confusing) message in your workflow output: 
`Invalid numeric literal`. Such messages are the direct output from the validation 
library <https://stedolan.github.io/jq/>. The supplied json must pass a run through `jq`, 
otherwise the workflow job will break with an error.

For CSV data, it must be a list value of values separated by `;` and ideally the values 
should be quoted with `"`. The values will be appended to the default set of fields that 
are sent. No header is added to the CSV, and the first 5 fields will always be 
`repository;ref;commit;event;workflow`. 


## License

The MIT License (MIT). Please see [License File](LICENSE) for more information.

[ico-release]: https://img.shields.io/github/tag/distributhor/webhook-action.svg
[ico-license]: https://img.shields.io/badge/license-MIT-brightgreen.svg
[link-github-release]: https://github.com/distributhor/workflow-webhook/releases