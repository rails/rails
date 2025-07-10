*   Update Security guide to account for changes to
    `content_security_policy_report_only`.

    Fixes #40452

    *Shaun Russell*

*   In the Active Job bug report template set the queue adapter to the
    test adapter so that `assert_enqueued_with` can pass.

    *Andrew White*

*   Ensure all bug report templates set `config.secret_key_base` to avoid
    generation of `tmp/local_secret.txt` files when running the report template.

    *Andrew White*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/guides/CHANGELOG.md) for previous changes.
