*   Add support for `with_routing` test helper in `ActionDispatch::IntegrationTest`

    *Gannon McGibbon*

*   Remove deprecated support to set `Rails.application.config.action_dispatch.show_exceptions` to `true` and `false`.

    *Rafael Mendonça França*

*   Remove deprecated `speaker`, `vibrate`, and `vr` permissions policy directives.

    *Rafael Mendonça França*

*   Remove deprecated `Rails.application.config.action_dispatch.return_only_request_media_type_on_content_type`.

    *Rafael Mendonça França*

*   Deprecate `Rails.application.config.action_controller.allow_deprecated_parameters_hash_equality`.

    *Rafael Mendonça França*

*   Remove deprecated comparison between `ActionController::Parameters` and `Hash`.

    *Rafael Mendonça França*

*   Remove deprecated constant `AbstractController::Helpers::MissingHelperError`.

    *Rafael Mendonça França*

*   Fix a race condition that could cause a `Text file busy - chromedriver`
    error with parallel system tests

    *Matt Brictson*

*   Add `racc` as a dependency since it will become a bundled gem in Ruby 3.4.0

    *Hartley McGuire*
*   Remove deprecated constant `ActionDispatch::IllegalStateError`.

    *Rafael Mendonça França*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/actionpack/CHANGELOG.md) for previous changes.
