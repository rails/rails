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


## Rails 5.2.0.beta2 (November 28, 2017) ##

*   Fix the gem adding the migrations files to the package.

    *Yuji Yaginuma*


## Rails 5.2.0.beta1 (November 27, 2017) ##

*   Added to Rails.

    *DHH*
