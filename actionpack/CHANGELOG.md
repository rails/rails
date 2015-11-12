## Rails 4.2.5 (November 12, 2015) ##

*   `ActionController::TestCase` can teardown gracefully if an error is raised
    early in the `setup` chain.

    *Yves Senn*

*   Parse RSS/ATOM responses as XML, not HTML.

    *Alexander Kaupanin*

*   Fix regression in mounted engine named routes generation for app deployed to
    a subdirectory. `relative_url_root` was prepended to the path twice (e.g.
    "/subdir/subdir/engine_path" instead of "/subdir/engine_path")

    Fixes #20920. Fixes #21459.

    *Matthew Erhard*

*   `url_for` does not modify its arguments when generating polymorphic URLs.

    *Bernerd Schaefer*

*   Update `ActionController::TestSession#fetch` to behave more like
    `ActionDispatch::Request::Session#fetch` when using non-string keys.

    *Jeremy Friesen*


## Rails 4.2.4 (August 24, 2015) ##

*   ActionController::TestSession now accepts a default value as well as
    a block for generating a default value based off the key provided.

    This fixes calls to session#fetch in ApplicationController instances that
    take more two arguments or a block from raising `ArgumentError: wrong
    number of arguments (2 for 1)` when performing controller tests.

    *Matthew Gerrior*

*   Fix to keep original header instance in `ActionDispatch::SSL`

    `ActionDispatch::SSL` changes headers to `Hash`.
    So some headers will be broken if there are some middlewares
    on `ActionDispatch::SSL` and if it uses `Rack::Utils::HeaderHash`.

    *Fumiaki Matsushima*


## Rails 4.2.3 (June 25, 2015) ##

*   Fix rake routes not showing the right format when
    nesting multiple routes.

    See #18373.

    *Ravil Bayramgalin*

*   Fix regression where a gzip file response would have a Content-type,
    even when it was a 304 status code.

    See #19271.

    *Kohei Suzuki*

*   Fix handling of empty X_FORWARDED_HOST header in raw_host_with_port

    Previously, an empty X_FORWARDED_HOST header would cause
    Actiondispatch::Http:URL.raw_host_with_port to return nil, causing
    Actiondispatch::Http:URL.host to raise a NoMethodError.

    *Adam Forsyth*

*   Fallback to `ENV['RAILS_RELATIVE_URL_ROOT']` in `url_for`.

    Fixed an issue where the `RAILS_RELATIVE_URL_ROOT` environment variable is not
    prepended to the path when `url_for` is called. If `SCRIPT_NAME` (used by Rack)
    is set, it takes precedence.

    Fixes #5122.

    *Yasyf Mohamedali*

*   Fix regression in functional tests. Responses should have default headers
    assigned.

    See #18423.

    *Jeremy Kemper*, *Yves Senn*


## Rails 4.2.2 (June 16, 2015) ##

* No Changes *


## Rails 4.2.1 (March 19, 2015) ##

*   Non-string authenticity tokens do not raise NoMethodError when decoding
    the masked token.

    *Ville Lautanala*

*   Explicitly ignored wildcard verbs when searching for HEAD routes before fallback

    Fixes an issue where a mounted rack app at root would intercept the HEAD
    request causing an incorrect behavior during the fall back to GET requests.

    Example:
    ```ruby
    draw do
        get '/home' => 'test#index'
        mount rack_app, at: '/'
    end
    head '/home'
    assert_response :success
    ```
    In this case, a HEAD request runs through the routes the first time and fails
    to match anything. Then, it runs through the list with the fallback and matches
    `get '/home'`. The original behavior would match the rack app in the first pass.

    *Terence Sun*

*   Preserve default format when generating URLs

    Fixes an issue that would cause the format set in default_url_options to be
    lost when generating URLs with fewer positional arguments than parameters in
    the route definition.

    Backport of #18627

    *Tekin Suleyman*, *Dominic Baggott*

*   Default headers, removed in controller actions, are no longer reapplied on
    the test response.

    *Jonas Baumann*

*   Ensure `append_info_to_payload` is called even if an exception is raised.

    Fixes an issue where when an exception is raised in the request the additonal
    payload data is not available.

    See:
    * #14903
    * https://github.com/roidrage/lograge/issues/37

    *Dieter Komendera*, *Margus Pärt*

*   Correctly rely on the response's status code to handle calls to `head`.

    *Robin Dupret*

*   Using `head` method returns empty response_body instead
    of returning a single space " ".

    The old behavior was added as a workaround for a bug in an early
    version of Safari, where the HTTP headers are not returned correctly
    if the response body has a 0-length. This is been fixed since and
    the workaround is no longer necessary.

    Fixes #18253.

    *Prathamesh Sonpatki*

*   Fix how polymorphic routes works with objects that implement `to_model`.

    *Travis Grathwell*

*   Fixed handling of positional url helper arguments when `format: false`.

    Fixes #17819.

    *Andrew White*, *Tatiana Soukiassian*

*   Fixed usage of optional scopes in URL helpers.

    *Alex Robbin*


## Rails 4.2.0 (December 20, 2014) ##

*   Add `ActionController::Parameters#to_unsafe_h` to return an unfiltered
    `Hash` representation of Parameters object. This is now a preferred way to
    retrieve unfiltered parameters as we will stop inheriting `AC::Parameters`
    object in Rails 5.0.

    *Prem Sichanugrist*

*   Restore handling of a bare `Authorization` header, without `token=`
    prefix.

    Fixes #17108.

    *Guo Xiang Tan*

*   Deprecate use of string keys in URL helpers.

    Use symbols instead.
    Fixes #16958.

    *Byron Bischoff*, *Melanie Gilman*

*   Deprecate the `only_path` option on `*_path` helpers.

    In cases where this option is set to `true`, the option is redundant and can
    be safely removed; otherwise, the corresponding `*_url` helper should be
    used instead.

    Fixes #17294.

    *Dan Olson*, *Godfrey Chan*

*   Improve Journey compliance to RFC 3986.

    The scanner in Journey failed to recognize routes that use literals
    from the sub-delims section of RFC 3986. It's now able to parse those
    authorized delimiters and route as expected.

    Fixes #17212.

    *Nicolas Cavigneaux*

*   Deprecate implicit Array conversion for Response objects. It was added
    (using `#to_ary`) so we could conveniently use implicit splatting:

        status, headers, body = response

    But it also means `response + response` works and `[response].flatten`
    cascades down to the Rack body. Nonsense behavior. Instead, rely on
    explicit conversion and splatting with `#to_a`:

        status, header, body = *response

    *Jeremy Kemper*

*   Don't rescue `IPAddr::InvalidAddressError`.

    `IPAddr::InvalidAddressError` does not exist in Ruby 1.9.3
    and fails for JRuby in 1.9 mode.

    *Peter Suschlik*

*   Fix bug where the router would ignore any constraints added to redirect
    routes.

    Fixes #16605.

    *Agis Anastasopoulos*

*   Allow `config.action_dispatch.trusted_proxies` to accept an IPAddr object.

    Example:

        # config/environments/production.rb
        config.action_dispatch.trusted_proxies = IPAddr.new('4.8.15.0/16')

    *Sam Aarons*

*   Avoid duplicating routes for HEAD requests.

    Instead of duplicating the routes, we will first match the HEAD request to
    HEAD routes. If no match is found, we will then map the HEAD request to
    GET routes.

    *Guo Xiang Tan*, *Andrew White*

*   Requests that hit `ActionDispatch::Static` can now take advantage
    of gzipped assets on disk. By default a gzip asset will be served if
    the client supports gzip and a compressed file is on disk.

    *Richard Schneeman*

*   `ActionController::Parameters` will stop inheriting from `Hash` and
    `HashWithIndifferentAccess` in the next major release. If you use any method
    that is not available on `ActionController::Parameters` you should consider
    calling `#to_h` to convert it to a `Hash` first before calling that method.

    *Prem Sichanugrist*

*   `ActionController::Parameters#to_h` now returns a `Hash` with unpermitted
    keys removed. This change is to reflect on a security concern where some
    method performed on an `ActionController::Parameters` may yield a `Hash`
    object which does not maintain `permitted?` status. If you would like to
    get a `Hash` with all the keys intact, duplicate and mark it as permitted
    before calling `#to_h`.

        params = ActionController::Parameters.new({
          name: 'Senjougahara Hitagi',
          oddity: 'Heavy stone crab'
        })
        params.to_h
        # => {}

        unsafe_params = params.dup.permit!
        unsafe_params.to_h
        # => {"name"=>"Senjougahara Hitagi", "oddity"=>"Heavy stone crab"}

        safe_params = params.permit(:name)
        safe_params.to_h
        # => {"name"=>"Senjougahara Hitagi"}

    This change is consider a stopgap as we cannot change the code to stop
    `ActionController::Parameters` to inherit from `HashWithIndifferentAccess`
    in the next minor release.

    *Prem Sichanugrist*

*   Deprecated `TagAssertions`.

    *Kasper Timm Hansen*

*   Use the Active Support JSON encoder for cookie jars using the `:json` or
    `:hybrid` serializer. This allows you to serialize custom Ruby objects into
    cookies by defining the `#as_json` hook on such objects.

    Fixes #16520.

    *Godfrey Chan*

*   Add `config.action_dispatch.cookies_digest` option for setting custom
    digest. The default remains the same - 'SHA1'.

    *Łukasz Strzałkowski*

*   Move `respond_with` (and the class-level `respond_to`) to
    the `responders` gem.

    *José Valim*

*   When your templates change, browser caches bust automatically.

    New default: the template digest is automatically included in your ETags.
    When you call `fresh_when @post`, the digest for `posts/show.html.erb`
    is mixed in so future changes to the HTML will blow HTTP caches for you.
    This makes it easy to HTTP-cache many more of your actions.

    If you render a different template, you can now pass the `:template`
    option to include its digest instead:

        fresh_when @post, template: 'widgets/show'

    Pass `template: false` to skip the lookup. To turn this off entirely, set:

        config.action_controller.etag_with_template_digest = false

    *Jeremy Kemper*

*   Remove deprecated `AbstractController::Helpers::ClassMethods::MissingHelperError`
    in favor of `AbstractController::Helpers::MissingHelperError`.

    *Yves Senn*

*   Fix `assert_template` not being able to assert that no files were rendered.

    *Guo Xiang Tan*

*   Extract source code for the entire exception stack trace for
    better debugging and diagnosis.

    *Ryan Dao*

*   Allows ActionDispatch::Request::LOCALHOST to match any IPv4 127.0.0.0/8
    loopback address.

    *Earl St Sauver*, *Sven Riedel*

*   Preserve original path in `ShowExceptions` middleware by stashing it as
    `env["action_dispatch.original_path"]`

    `ActionDispatch::ShowExceptions` overwrites `PATH_INFO` with the status code
    for the exception defined in `ExceptionWrapper`, so the path
    the user was visiting when an exception occurred was not previously
    available to any custom exceptions_app. The original `PATH_INFO` is now
    stashed in `env["action_dispatch.original_path"]`.

    *Grey Baker*

*   Use `String#bytesize` instead of `String#size` when checking for cookie
    overflow.

    *Agis Anastasopoulos*

*   `render nothing: true` or rendering a `nil` body no longer add a single
    space to the response body.

    The old behavior was added as a workaround for a bug in an early version of
    Safari, where the HTTP headers are not returned correctly if the response
    body has a 0-length. This is been fixed since and the workaround is no
    longer necessary.

    Use `render body: ' '` if the old behavior is desired.

    See #14883 for details.

    *Godfrey Chan*

*   Prepend a JS comment to JSONP callbacks. Addresses CVE-2014-4671
    ("Rosetta Flash").

    *Greg Campbell*

*   Because URI paths may contain non US-ASCII characters we need to force
    the encoding of any unescaped URIs to UTF-8 if they are US-ASCII.
    This essentially replicates the functionality of the monkey patch to
    URI.parser.unescape in active_support/core_ext/uri.rb.

    Fixes #16104.

    *Karl Entwistle*

*   Generate shallow paths for all children of shallow resources.

    Fixes #15783.

    *Seb Jacobs*

*   JSONP responses are now rendered with the `text/javascript` content type
    when rendering through a `respond_to` block.

    Fixes #15081.

    *Lucas Mazza*

*   Add `config.action_controller.always_permitted_parameters` to configure which
    parameters are permitted globally. The default value of this configuration is
    `['controller', 'action']`.

    *Gary S. Weaver*, *Rafael Chacon*

*   Fix env['PATH_INFO'] missing leading slash when a rack app mounted at '/'.

    Fixes #15511.

    *Larry Lv*

*   ActionController::Parameters#require now accepts `false` values.

    Fixes #15685.

    *Sergio Romano*

*   With authorization header `Authorization: Token token=`, `authenticate` now
    recognize token as nil, instead of "token".

    Fixes #14846.

    *Larry Lv*

*   Ensure the controller is always notified as soon as the client disconnects
    during live streaming, even when the controller is blocked on a write.

    *Nicholas Jakobsen*, *Matthew Draper*

*   Routes specifying 'to:' must be a string that contains a "#" or a rack
    application.  Use of a symbol should be replaced with `action: symbol`.
    Use of a string without a "#" should be replaced with `controller: string`.

    *Aaron Patterson*

*   Fix URL generation with `:trailing_slash` such that it does not add
    a trailing slash after `.:format`

    *Dan Langevin*

*   Build full URI as string when processing path in integration tests for
    performance reasons. One consequence of this is that the leading slash
    is now required in integration test `process` helpers, whereas previously
    it could be omitted. The fact that this worked was a unintended consequence
    of the implementation and was never an intentional feature.

    *Guo Xiang Tan*

*   Fix `'Stack level too deep'` when rendering `head :ok` in an action method
    called 'status' in a controller.

    Fixes #13905.

    *Christiaan Van den Poel*

*   Add MKCALENDAR HTTP method (RFC 4791).

    *Sergey Karpesh*

*   Instrument fragment cache metrics.

    Adds `:controller`: and `:action` keys to the instrumentation payload
    for the `*_fragment.action_controller` notifications. This allows tracking
    e.g. the fragment cache hit rates for each controller action.

    *Daniel Schierbeck*

*   Always use the provided port if the protocol is relative.

    Fixes #15043.

    *Guilherme Cavalcanti*, *Andrew White*

*   Moved `params[request_forgery_protection_token]` into its own method
    and improved tests.

    Fixes #11316.

    *Tom Kadwill*

*   Added verification of route constraints given as a Proc or an object responding
    to `:matches?`. Previously, when given an non-complying object, it would just
    silently fail to enforce the constraint. It will now raise an `ArgumentError`
    when setting up the routes.

    *Xavier Defrang*

*   Properly treat the entire IPv6 User Local Address space as private for
    purposes of remote IP detection. Also handle uppercase private IPv6
    addresses.

    Fixes #12638.

    *Caleb Spare*

*   Fixed an issue with migrating legacy json cookies.

    Previously, the `VerifyAndUpgradeLegacySignedMessage` assumes all incoming
    cookies are marshal-encoded. This is not the case when `secret_token` is
    used in conjunction with the `:json` or `:hybrid` serializer.

    In those case, when upgrading to use `secret_key_base`, this would cause a
    `TypeError: incompatible marshal file format` and a 500 error for the user.

    Fixes #14774.

    *Godfrey Chan*

*   Make URL escaping more consistent:

    1. Escape '%' characters in URLs - only unescaped data should be passed to URL helpers
    2. Add an `escape_segment` helper to `Router::Utils` that escapes '/' characters
    3. Use `escape_segment` rather than `escape_fragment` in optimized URL generation
    4. Use `escape_segment` rather than `escape_path` in URL generation

    For point 4 there are two exceptions. Firstly, when a route uses wildcard segments
    (e.g. `*foo`) then we use `escape_path` as the value may contain '/' characters. This
    means that wildcard routes can't be optimized. Secondly, if a `:controller` segment
    is used in the path then this uses `escape_path` as the controller may be namespaced.

    Fixes #14629, #14636 and #14070.

    *Andrew White*, *Edho Arief*

*   Add alias `ActionDispatch::Http::UploadedFile#to_io` to
    `ActionDispatch::Http::UploadedFile#tempfile`.

    *Tim Linquist*

*   Returns null type format when format is not know and controller is using `any`
    format block.

    Fixes #14462.

    *Rafael Mendonça França*

*   Improve routing error page with fuzzy matching search.

    *Winston*

*   Only make deeply nested routes shallow when parent is shallow.

    Fixes #14684.

    *Andrew White*, *James Coglan*

*   Append link to bad code to backtrace when exception is `SyntaxError`.

    *Boris Kuznetsov*

*   Swapped the parameters of assert_equal in `assert_select` so that the
    proper values were printed correctly.

    Fixes #14422.

    *Vishal Lal*

*   The method `shallow?` returns false if the parent resource is a singleton so
    we need to check if we're not inside a nested scope before copying the :path
    and :as options to their shallow equivalents.

    Fixes #14388.

    *Andrew White*

*   Make logging of CSRF failures optional (but on by default) with the
    `log_warning_on_csrf_failure` configuration setting in
    `ActionController::RequestForgeryProtection`.

    *John Barton*

*   Fix URL generation in controller tests with request-dependent
    `default_url_options` methods.

    *Tony Wooster*

Please check [4-1-stable](https://github.com/rails/rails/blob/4-1-stable/actionpack/CHANGELOG.md) for previous changes.
