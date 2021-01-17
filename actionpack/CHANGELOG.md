## Unreleased

*   Add `config.action_dispatch.conceal_request_body_on_parse_error` to toggle whether the raw post body is included in log messages
    and exception messages on parse error. The default behavior of including the raw post body remains the same in test and development
    environments. However, the default behavior of other environments (production) is to now omit the raw post body to avoid leaking
    potentially sensitive information in logs.

    *Aaron Lahey*

*   Change the request method to a `GET` when passing failed requests down to `config.exceptions_app`.

    *Alex Robbin*

*   Add `redirect_back_or_to(fallback_location, **)` as a more aesthetically pleasing version of `redirect_back fallback_location:, **`.
    The old method name is retained without explicit deprecation.

    *DHH*


Please check [6-1-stable](https://github.com/rails/rails/blob/6-1-stable/actionpack/CHANGELOG.md) for previous changes.
