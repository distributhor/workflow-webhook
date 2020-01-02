# Workflow Webhook Action

[![GitHub Release][ico-release]][link-github-release]
[![License][ico-license]](LICENSE)

Github workflow action to push to webhook

<hr/>

## Usage

Sending a string:

```yml
    - name: Call deployment hook [staging]
      uses: distributhor/workflow-webhook@master
      env:
        webhook_url: ${{ secrets.WEBHOOK_URL_STAGING }}
        webhook_secret: ${{ secrets.WEBHOOK_SECRET_STAGING }}
        data_json: '{ "deployment ": "finished", "project" : "actions" } '
        data_csv: 'This is an additional custom field'
        data_type: 'csv'
```


### Arguments

* ```yml 
  data: "Hello from github actions!"
  ```

* ```yml
  data: "{'deployment': 'finished', 'project': 'actions'}"
  ```

## Validation

Invalid numeric literal


## License

The MIT License (MIT). Please see [License File](LICENSE) for more information.

[ico-release]: https://img.shields.io/github/tag/distributhor/webhook-action.svg
[ico-license]: https://img.shields.io/badge/license-MIT-brightgreen.svg
[link-github-release]: https://github.com/distributhor/workflow-webhook/releases