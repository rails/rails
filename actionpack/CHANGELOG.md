*   Fix an issue where rails raise exception about missing helper where it
    should throw `LoadError`. When helper file exists and only loaded file from
    this helper does not exist rails should throw LoadError instead of
    `MissingHelperError`.

    *Piotr Niełacny*

*   Fix `ActionDispatch::ParamsParser#parse_formatted_parameters` to rewind body input stream on
    parsing json params.

    Fixes #11345

    *Yuri Bol*, *Paul Nikitochkin*

*   Ignore spaces around delimiter in Set-Cookie header.

    *Yamagishi Kazutoshi*

*   Remove deprecated Rails application fallback for integration testing, set
    `ActionDispatch.test_app` instead.

    *Carlos Antonio da Silva*

*   Remove deprecated `page_cache_extension` config.

    *Francesco Rodriguez*

*   Remove deprecated constants from Action Controller:

        ActionController::AbstractRequest  => ActionDispatch::Request
        ActionController::Request          => ActionDispatch::Request
        ActionController::AbstractResponse => ActionDispatch::Response
        ActionController::Response         => ActionDispatch::Response
        ActionController::Routing          => ActionDispatch::Routing
        ActionController::Integration      => ActionDispatch::Integration
        ActionController::IntegrationTest  => ActionDispatch::IntegrationTest

    *Carlos Antonio da Silva*

*   Fix `Mime::Type.parse` when bad accepts header is looked up. Previously it
    was setting `request.formats` with an array containing a `nil` value, which
    raised an error when setting the controller formats.

    Fixes #10965

    *Becker*

*   Merge `:action` from routing scope and assign endpoint if both `:controller`
    and `:action` are present. The endpoint assignment only occurs if there is
    no `:to` present in the options hash so should only affect routes using the
    shorthand syntax (i.e. endpoint is inferred from the path).

    Fixes #9856

    *Yves Senn*, *Andrew White*

*   ActionView extracted from ActionPack

    *Piotr Sarnacki*, *Łukasz Strzałkowski*

*   Fix removing trailing slash for mounted apps #3215

    *Piotr Sarnacki*

Please check [4-0-stable](https://github.com/rails/rails/blob/4-0-stable/actionpack/CHANGELOG.md) for previous changes.
