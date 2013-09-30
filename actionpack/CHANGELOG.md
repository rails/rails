*   Fix `ActionDispatch::RemoteIp::GetIp#calculate_ip` to only check for spoofing
    attacks if both `HTTP_CLIENT_IP` and `HTTP_X_FORWARDED_FOR` are set.

    Fixes #10844

    *Tamir Duberstein*

*   Strong parameters should permit nested number as key.

    Fixes #12293

    *kennyj*

*   Fix regex used to detect URI schemes in `redirect_to` to be consistent with
    RFC 3986.

    *Derek Prior*

*   Fix incorrect `assert_redirected_to` failure message for protocol-relative
    URLs.

    *Derek Prior*

*   Fix an issue where router can't recognize downcased url encoding path.

    Fixes #12269

    *kennyj*

*   Fix custom flash type definition. Misusage of the `_flash_types` class variable
    caused an error when reloading controllers with custom flash types.

    Fixes #12057

    *Ricardo de Cillo*

*   Do not break params filtering on `nil` values.

    Fixes #12149.

    *Vasiliy Ermolovich*

*   Separate Action View completely from Action Pack.

    *Łukasz Strzałkowski*

*   Development mode exceptions are rendered in text format in case of XHR request.

    *Kir Shatrov*

*   Fix an issue where :if and :unless controller action procs were being run
    before checking for the correct action in the :only and :unless options.

    Fixes #11799

    *Nicholas Jakobsen*

*   Fix an issue where `assert_dom_equal` and `assert_dom_not_equal` were
    ignoring the passed failure message argument.

    Fixes #11751

    *Ryan McGeary*

*   Allow REMOTE_ADDR, HTTP_HOST and HTTP_USER_AGENT to be overridden from
    the environment passed into `ActionDispatch::TestRequest.new`.

    Fixes #11590

    *Andrew White*

*   Fix an issue where Journey was failing to clear the named routes hash when the
    routes were reloaded and since it doesn't overwrite existing routes then if a
    route changed but wasn't renamed it kept the old definition. This was being
    masked by the optimised url helpers so it only became apparent when passing an
    options hash to the url helper.

    *Andrew White*

*   Skip routes pointing to a redirect or mounted application when generating urls
    using an options hash as they aren't relevant and generate incorrect urls.

    Fixes #8018

    *Andrew White*

*   Move `MissingHelperError` out of the `ClassMethods` module.

    *Yves Senn*

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
