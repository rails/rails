## Rails 5.2.1.1 (November 27, 2018) ##

*   Prevent content type and disposition bypass in storage service URLs.

    Fix CVE-2018-16477.

    *Rosa Gutierrez*


## Rails 5.2.1 (August 07, 2018) ##

*   Fix direct upload with zero-byte files.

    *George Claghorn*

*   Exclude JSON root from `active_storage/direct_uploads#create` response.

    *Javan Makhmali*


## Rails 5.2.0 (April 09, 2018) ##

*   Allow full use of the AWS S3 SDK options for authentication. If an
    explicit AWS key pair and/or region is not provided in `storage.yml`,
    attempt to use environment variables, shared credentials, or IAM
    (instance or task) role credentials. Order of precedence is determined
    by the [AWS SDK](https://docs.aws.amazon.com/sdk-for-ruby/v3/developer-guide/setup-config.html).

    *Brian Knight*

*   Remove path config option from Azure service.

    The Active Storage service for Azure Storage has an option called `path`
    that is ambiguous in meaning. It needs to be set to the primary blob
    storage endpoint but that can be determined from the blobs client anyway.

    To simplify the configuration, we've removed the `path` option and
    now get the endpoint from the blobs client instead.

    Closes #32225.

    *Andrew White*

*   Generate root-relative paths in disk service URL methods.

    Obviate the disk service's `:host` configuration option.

    *George Claghorn*

*   Add source code to published npm package.

    This allows activestorage users to depend on the javascript source code
    rather than the compiled code, which can produce smaller javascript bundles.

    *Richard Macklin*

*   Preserve display aspect ratio when extracting width and height from videos
    with rectangular samples in `ActiveStorage::Analyzer::VideoAnalyzer`.

    When a video contains a display aspect ratio, emit it in metadata as
    `:display_aspect_ratio` rather than the ambiguous `:aspect_ratio`. Compute
    its height by scaling its encoded frame width according to the DAR.

    *George Claghorn*

*   Use `after_destroy_commit` instead of `before_destroy` for purging
    attachments when a record is destroyed.

    *Hiroki Zenigami*

*   Force `:attachment` disposition for specific, configurable content types.
    This mitigates possible security issues such as XSS or phishing when
    serving them inline. A list of such content types is included by default,
    and can be configured via `content_types_to_serve_as_binary`.

    *Rosa Gutierrez*

*   Fix the gem adding the migrations files to the package.

    *Yuji Yaginuma*

*   Added to Rails.

    *DHH*
