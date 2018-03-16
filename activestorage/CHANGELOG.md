*   Allow the use of the AWS Credentials Provider chain for S3 storage. If
    an explicit AWS access key id and secret access key are not provided in
    `storage.yml`, attempt to use environment variables, shared credentials,
    or IAM (instance or task) role credentials. Order of precedence is
    determined by the [AWS SDK].(https://docs.aws.amazon.com/sdk-for-ruby/v3/developer-guide/setup-config.html)

    *Brian Knight*

*   Rails 6 requires Ruby 2.4.1 or newer.

    *Jeremy Daer*


Please check [5-2-stable](https://github.com/rails/rails/blob/5-2-stable/activestorage/CHANGELOG.md) for previous changes.
