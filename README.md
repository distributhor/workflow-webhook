# Workflow Webhook Action

[![GitHub Release][ico-release]][link-github-release]
[![License][ico-license]](LICENSE)

A Github workflow action to call (POST) a remote webhook endpoint with a json or form-urlencoded
payload, and support for BASIC authentication. A hash signature is passed with each request, 
derived from the payload and a configurable secret token. The hash signature is 
identical to that which a regular Github webhook would generate, and sent in a header 
field named `X-Hub-Signature`. Therefore any existing Github webhook signature 
validation will continue to work. For more information on how to valiate the signature, 
see <https://developer.github.com/webhooks/securing>.

By default, the values of the following GitHub workflow environment variables are sent in the 
payload: `GITHUB_REPOSITORY`, `GITHUB_REF`, `GITHUB_HEAD_REF`, `GITHUB_SHA`, `GITHUB_EVENT_NAME` 
and `GITHUB_WORKFLOW`. For more information on what is contained in these variables, see 
<https://help.github.com/en/actions/automating-your-workflow-with-github-actions/using-environment-variables>. 

These values map to the payload as follows:

```json
{
    "event": "GITHUB_EVENT_NAME",
    "repository": "GITHUB_REPOSITORY",
    "commit": "GITHUB_SHA",
    "ref": "GITHUB_REF",
    "head": "GITHUB_HEAD_REF",
    "workflow": "GITHUB_WORKFLOW"
}
```

Additional (custom) data can be added to the payload as well (see further down).


## Usage

The following are example snippets for a Github yaml workflow configuration. <br/>

Send the JSON (default) payload to a webhook:

```yml
    - name: Invoke deployment hook
      uses: distributhor/workflow-webhook@v1
      env:
        webhook_url: ${{ secrets.WEBHOOK_URL }}
        webhook_secret: ${{ secrets.WEBHOOK_SECRET }}
```

Will deliver a payload with the following properties:

```json
{
    "event": "push",
    "repository": "owner/project",
    "commit": "a636b6f0861bbee98039bf3df66ee13d8fbc9c74",
    "ref": "refs/heads/master",
    "head": "",
    "workflow": "Build and deploy"
}
```
<br/>

Add additional data to the payload:

```yml
    - name: Invoke deployment hook
      uses: distributhor/workflow-webhook@v1
      env:
        webhook_url: ${{ secrets.WEBHOOK_URL }}
        webhook_secret: ${{ secrets.WEBHOOK_SECRET }}
        data: '{ "weapon": "hammer", "drink" : "beer" }'
```

The additional information will become available on a 'data' property,
and now look like:

```json
{
    "event": "push",
    "repository": "owner/project",
    "commit": "a636b6f0861bbee98039bf3df66ee13d8fbc9c74",
    "ref": "refs/heads/master",
    "head": "",
    "workflow": "Build and deploy",
    "data": {
        "weapon": "hammer",
        "drink": "beer"
    }
}
```

Send a form-urlencoded payload instead:

```yml
    - name: Invoke deployment hook
      uses: distributhor/workflow-webhook@v1
      env:
        webhook_type: 'form-urlencoded'
        webhook_url: ${{ secrets.WEBHOOK_URL }}
        webhook_secret: ${{ secrets.WEBHOOK_SECRET }}
        data: 'weapon=hammer&drink=beer'
```

Will set the `Content-Type` header to `application/x-www-form-urlencoded` and deliver:

```csv
"even=push&repository=owner/project&commit=a636b6f0861bbee98039bf3df66ee13d8fbc9c74&ref=refs/heads/master&head=&weapon=hammer&drink=beer"
```

## Arguments

```yml 
  webhook_url: "https://your.webhook"
```

*Required*. The HTTP URI of the webhook endpoint to invoke. The endpoint must accept 
an HTTP POST request. <br/><br/>


```yml 
  webhook_secret: "Y0uR5ecr3t"
```

*Required*. The secret with which to generate the signature hash. <br/><br/>

```yml 
  webhook_auth: "username:password"
```

Credentials to be used for BASIC authentication against the endpoint. If not configured,
authentication is assumed not to be required. If configured, it must follow the format
`username:password`, which will be used as the BASIC auth credential.<br/><br/>

```yml 
  webhook_type: "json | form-urlencoded"
```

The default endpoint type is json. The argument is only required if you wish to send urlencoded form data. 
Otherwise it's optional. <br/><br/>

```yml 
  data: "Additional json"
```

Additional data to include in the payload. The argument is optional if the default 
fields are sufficient and you wish to provide no further information.

The custom data will be available on a property named `data`, and it will be run through 
a json validator. Invalid json will cause the action to break and exit. For example, using 
single quotes for json properties and values instead of double quotes, will show the 
following (somewhat confusing) message in your workflow output: `Invalid numeric literal`. 
Such messages are the direct output from the validation library <https://stedolan.github.io/jq/>. 
The supplied json must pass the validation run through `jq`.


## License

The MIT License (MIT). Please see [License File](LICENSE) for more information.

[ico-release]: https://img.shields.io/github/tag/distributhor/workflow-webhook.svg
[ico-license]: https://img.shields.io/badge/license-MIT-brightgreen.svg
[link-github-release]: https://github.com/distributhor/workflow-webhook/releases
