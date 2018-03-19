*   Allow full use of the AWS S3 SDK options for authentication. If an
    explicit AWS key pair and/or region is not provided in  `storage.yml`, 
    attempt to use environment variables, shared credentials, or IAM 
    (instance or task) role credentials. Order of precedence is determined 
    by the [AWS SDK](https://docs.aws.amazon.com/sdk-for-ruby/v3/developer-guide/setup-config.html).

    *Brian Knight*

*   Rails 6 requires Ruby 2.4.1 or newer.

    *Jeremy Daer*


Please check [5-2-stable](https://github.com/rails/rails/blob/5-2-stable/activestorage/CHANGELOG.md) for previous changes.
