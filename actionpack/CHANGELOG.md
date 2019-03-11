## Rails 5.0.7.2 (March 11, 2019) ##

*   No changes.


## Rails 5.0.7.1 (November 27, 2018) ##

*   No changes.


## Rails 5.0.7 (March 29, 2018) ##

*   Remove deprecation on `ActionController::Parameters#to_hash` when the instance is
    permitted.

    *Edouard Chin*


## Rails 5.0.6 (September 07, 2017) ##

*   No changes.


## Rails 5.0.6.rc1 (August 24, 2017) ##

*   No changes.


## Rails 5.0.5 (July 31, 2017) ##

*   No changes.


## Rails 5.0.5.rc2 (July 25, 2017) ##

*   No changes.


## Rails 5.0.5.rc1 (July 19, 2017) ##

*   Fallback `ActionController::Parameters#to_s` to `Hash#to_s`.

    *Kir Shatrov*


## Rails 5.0.4 (June 19, 2017) ##

*   No changes.


## Rails 5.0.3 (May 12, 2017) ##

*   Raise exception when calling `to_h` in an unfiltered Parameters.

    This method will raise on unfiltered Parameters if
    `config.action_controller.raise_on_unfiltered_parameters` is true.

    Before we returned either an empty hash or only the always permitted parameters
    (`:controller` and `:action` by default).

    The previous behavior was dangerous because in order to get the attributes users
    usually fallback to use `to_unsafe_h` that could potentially introduce security issues.

    *Rafael Mendonça França*

*   Add `ActionController::Parameters#to_hash` to implicit conversion.

    Now methods that implicit convert objects to a hash will be able to work without
    requiring the users to change their implementation.

    This method will return a `Hash` instead of a `ActiveSupport::HashWithIndefirentAccess`
    to mimic the same implementation of `ActiveSupport::HashWithIndefirentAccess#to_hash`.

    This method will raise on unfiltered Parameters if
    `config.action_controller.raise_on_unfiltered_parameters` is true.

    *Rafael Mendonça França*

*   Undeprecate `ActionController::Parameters#to_query` and `#to_param`.

    Previously it was raising a deprecation because it may be unsafe to use those methods
    in an unfiltered parameter. Now we delegate to `#to_h` that already raise an error when
    the Parameters instance is not permitted.

    This also fix a bug when using `#to_query` in a hash that contains a
    `ActionController::Parameters` instance and was returning the name of the class in the
    string.

    *Rafael Mendonça França*

*   Use more specific check for :format in route path

    The current check for whether to add an optional format to the path is very lax
    and will match things like `:format_id` where there are nested resources, e.g:

    ``` ruby
    resources :formats do
      resources :items
    end
    ```

    Fix this by using a more restrictive regex pattern that looks for the patterns
    `(.:format)`, `.:format` or `/` at the end of the path. Note that we need to
    allow for multiple closing parenthesis since the route may be of this form:

    ``` ruby
    get "/books(/:action(.:format))", controller: "books"
    ```

    This probably isn't what's intended since it means that the default index action
    route doesn't support a format but we have a test for it so we need to allow it.

    Fixes #28517.

    *Andrew White*

*   Don't include default headers in `ActionController::Metal` responses

    The commit e16afe6 introduced an unintentional change of behavior where the default
    headers were included in responses from `ActionController::Metai` based controllers.
    This is now reverted to the previous behavior of having no default headers.

    Fixes #25820.

    *Jon Moss*

*   Fix malformed URLS when using `ApplicationController.renderer`

    The Rack environment variable `rack.url_scheme` was not being set so `scheme` was
    returning `nil`. This caused URLs to be malformed with the default settings.
    Fix this by setting `rack.url_scheme` when the environment is normalized.

    Fixes #28151.

    *George Vrettos*

*   Commit flash changes when using a redirect route.

    Fixes #27992.

    *Andrew White*


## Rails 5.0.2 (March 01, 2017) ##

*   Make `with_routing` test helper work when testing controllers inheriting from `ActionController::API`.

    *Julia López*


## Rails 5.0.1 (December 21, 2016) ##

*   Restored correct `charset` behavior on `send_data` and `send_file`: while
    they should pass along any supplied value, they should not add a default.

    Fixes #27344.

    *Matthew Draper*


## Rails 5.0.1.rc2 (December 10, 2016) ##

*   Move `cookies`, `flash`, and `session` methods back to
    `ActionDispatch::Integration::Session`.

    *Matthew Draper*

*   Do not reset in `ActionDispatch::IntegrationTest#open_session`; doing so
    is incompatible with existing (unintended) API usage.

    *Sean Griffin*


## Rails 5.0.1.rc1 (December 01, 2016) ##

*   Fixed error caused by `force_ssl_redirect` when `session_store` is
    enabled.

    Fixes #19679.

    *Taishi Kasuga*

*   Use accept header in integration tests with `as: :json`

    Instead of appending the `format` to the request path. Rails will figure
    out the format from the header instead.

    This allows devs to use `:as` on routes that don't have a format.

    Fixes #27144.

    *Kasper Timm Hansen*

*   Fixed integration test requests appending and changing request paths.

        #Before
        post "/anything", params: params, headers: headers, as: :json

    "/anything" would be converted to "/anything.json" based on format.
    The path is now maintained and the format is respected based on `:as`
    option.

    Fixes #27144.

*   Fixes incorrect output from rails routes when using singular resources.

    Fixes #26606.

    *Erick Reyna*

*   Fixes multiple calls to `logger.fatal` instead of a single call,
    for every line in an exception backtrace, when printing trace
    from `DebugExceptions` middleware.

    Fixes #26134.

    *Vipul A M*

*   Add `ActionController::Parameters#merge!`, which behaves the same as `Hash#merge!`.

    *Yuji Yaginuma*

*   Added `ActionController::Parameters#deep_dup` which actually creates
    a params copy, instead of refereing to old references in params.

    Fixes #26566.

    *Pavel Evstigneev*, *Rafael Mendonça França*

*   Make `fixture_file_upload` work in integration tests.

    *Yuji Yaginuma*

*   Add `to_param` to `ActionController::Parameters` deprecations.

    In the future `ActionController::Parameters` are discouraged from being used
    in URLs without explicit whitelisting. Go through `to_h` to use `to_param`.

    *Kir Shatrov*

*   Fix nested multiple roots

    The PR #20940 enabled the use of multiple roots with different constraints
    at the top level but unfortunately didn't work when those roots were inside
    a namespace and also broke the use of root inside a namespace after a top
    level root was defined because the check for the existence of the named route
    used the global :root name and not the namespaced name.

    This is fixed by using the name_for_action method to expand the :root name to
    the full namespaced name. We can pass nil for the second argument as we're not
    dealing with resource definitions so don't need to handle the cases for edit
    and new routes.

    Fixes #26148.

    *Ryo Hashimoto*, *Andrew White*

*   SSL: Changes redirect behavior for all non-GET and non-HEAD requests
    (like POST/PUT/PATCH etc) to `http://` resources to redirect to `https://`
    with a [307 status code](http://tools.ietf.org/html/rfc7231#section-6.4.7) instead of [301 status code](http://tools.ietf.org/html/rfc7231#section-6.4.2).

    307 status code instructs the HTTP clients to preserve the original
    request method while redirecting. It has been part of HTTP RFC since
    1999 and is implemented/recognized by most (if not all) user agents.

        # Before
        POST http://example.com/articles (i.e. ArticlesContoller#create)
        redirects to
        GET https://example.com/articles (i.e. ArticlesContoller#index)

        # After
        POST http://example.com/articles (i.e. ArticlesContoller#create)
        redirects to
        POST https://example.com/articles (i.e. ArticlesContoller#create)

    *Chirag Singhal*

*   Add `:as` option to `ActionController:TestCase#process` and related methods.

    Specifying `as: mime_type` allows the `CONTENT_TYPE` header to be specified
    in controller tests without manually doing this through `@request.headers['CONTENT_TYPE']`.

    *Everest Stefan Munro-Zeisberger*

*   Prevent autoload from deadlocking while ActionController::Live is streaming.

    *Alex Chinn*

*   Don't override the `Accept` header in integration tests when called with `xhr: true`.

    Fixes #25859.

    *David Chen*

*   Reset a new session directly after its creation in `ActionDispatch::IntegrationTest#open_session`.

    Fixes #22742.

    *Tawan Sierek*

*   Fix 'defaults' option for root route.

    A regression from some refactoring for the 5.0 release, this change
    fixes the use of 'defaults' (default parameters) in the 'root' routing method.

    *Chris Arcand*

*   Check `request.path_parameters` encoding at the point they're set.

    Check for any non-UTF8 characters in path parameters at the point they're
    set in `env`. Previously they were checked for when used to get a controller
    class, but this meant routes that went directly to a Rack app, or skipped
    controller instantiation for some other reason, had to defend against
    non-UTF8 characters themselves.

    *Grey Baker*

*   Don't raise ActionController::UnknownHttpMethod from ActionDispatch::Static

    Pass `Rack::Request` objects to `ActionDispatch::FileHandler` to avoid it
    raising `ActionController::UnknownHttpMethod`. If an unknown method is
    passed, it should exception higher in the stack instead, once we've had a
    chance to define exception handling behaviour.

    *Grey Baker*

*   Handle `Rack::QueryParser` errors in `ActionDispatch::ExceptionWrapper`

    Updated `ActionDispatch::ExceptionWrapper` to handle the Rack 2.0 namespace
    for `ParameterTypeError` and `InvalidParameterError` errors.

    *Grey Baker*

*   Deprecated omitting the route path.
    Specify the path with a String or a Symbol instead.

        # Before
        get action: :show, as: :show
        # After
        get "", action: :show, as: :show

    *Volmer*

*   Added new `ActionDispatch::DebugLocks` middleware that can be used
    to diagnose deadlocks in the autoload interlock.
    To use it, insert it near the top of the middleware stack, using
    `config/application.rb`:

        config.middleware.insert_before Rack::Sendfile, ActionDispatch::DebugLocks

    After adding, visiting `/rails/locks` will show a summary of all
    threads currently known to the interlock.

    *Matthew Draper*

*   Fix request encoding in Integration tests when string literals are
    frozen using `--enable-frozen-string-literal` or `# frozen_string_literal: true`.

    *Volmer*

*   Since long keys are truncated when passed to ciphers, Ruby 2.4
    doesn't accept keys greater than their max length.
    Fixed default key length on cipher for `ActiveSupport::MessageEncryptor`,
    which was causing errors on Ruby 2.4.

    *Vipul A M*

*   Fixed adding implicitly rendered template digests to ETags.
    Properly ignore implicit template cache option to ETag, if `template: false`
    is passed when rendering.

    *Javan Makhmali*


## Rails 5.0.0 (June 30, 2016) ##

*   Add `ActionController#helpers` to get access to the view context at the controller
    level.

    *Rafael Mendonça França*

*   Routing: Refactor `:action` default handling to ensure that path
    parameters are not mutated during route generation.

    *Andrew White*

*   Add extension synonyms `yml` and `yaml` for MIME type `application/x-yaml`.

    *bogdanvlviv*

*   Adds support for including ActionController::Cookies in API controllers.
    Previously, including the module would raise when trying to define
    a `cookies` helper method. Skip calling #helper_method if it is not
    defined -- if we don't have helpers, we needn't define one.

    Fixes #24304

    *Ryan T. Hosford*

*   ETags: Introduce `Response#strong_etag=` and `#weak_etag=` and analogous
    options for `fresh_when` and `stale?`. `Response#etag=` sets a weak ETag.

    Strong ETags are desirable when you're serving byte-for-byte identical
    responses that support Range requests, like PDFs or videos (typically
    done by reproxying the response from a backend storage service).
    Also desirable when fronted by some CDNs that support strong ETags
    only, like Akamai.

    *Jeremy Daer*

*   ETags: No longer strips quotes (") from ETag values before comparing them.
    Quotes are significant, part of the ETag. A quoted ETag and an unquoted
    one are not the same entity.

    *Jeremy Daer*

*   ETags: Support `If-None-Match: *`. Rarely useful for GET requests; meant
    to provide some optimistic concurrency control for PUT requests.

    *Jeremy Daer*

*   `ActionDispatch::ParamsParser` is deprecated and was removed from the middleware
    stack. To configure the parameter parsers use `ActionDispatch::Request.parameter_parsers=`.

    *tenderlove*

*   When a `respond_to` collector with a block doesn't have a response, then
    a `:no_content` response should be rendered.  This brings the default
    rendering behavior introduced by https://github.com/rails/rails/issues/19036
    to controller methods employing `respond_to`.

    *Justin Coyne*

*   Add `ActionController::Parameters#dig` on Ruby 2.3 and greater, which
    behaves the same as `Hash#dig`.

    *Sean Griffin*

*   Add request headers in the payload of the `start_processing.action_controller`
    and `process_action.action_controller` notifications.

    *Gareth du Plooy*

*   Add `action_dispatch_integration_test` load hook. The hook can be used to
    extend `ActionDispatch::IntegrationTest` once it has been loaded.

    *Yuichiro Kaneko*

*   Update default rendering policies when the controller action did
    not explicitly indicate a response.

    For API controllers, the implicit render always renders "204 No Content"
    and does not account for any templates.

    For other controllers, the following conditions are checked:

    First, if a template exists for the controller action, it is rendered.
    This template lookup takes into account the action name, locales, format,
    variant, template handlers, etc. (see `render` for details).

    Second, if other templates exist for the controller action but is not in
    the right format (or variant, etc.), an `ActionController::UnknownFormat`
    is raised. The list of available templates is assumed to be a complete
    enumeration of all the possible formats (or variants, etc.); that is,
    having only HTML and JSON templates indicate that the controller action is
    not meant to handle XML requests.

    Third, if the current request is an "interactive" browser request (the user
    navigated here by entering the URL in the address bar, submitting a form,
    clicking on a link, etc. as opposed to an XHR or non-browser API request),
    `ActionView::UnknownFormat` is raised to display a helpful error
    message.

    Finally, it falls back to the same "204 No Content" behavior as API controllers.

    *Godfrey Chan*, *Jon Moss*, *Kasper Timm Hansen*, *Mike Clark*, *Matthew Draper*

*   Add "application/gzip" as a default mime type.

    *Mehmet Emin İNAÇ*

*   Add request encoding and response parsing to integration tests.

    What previously was:

    ```ruby
    require 'test_helper'

    class ApiTest < ActionDispatch::IntegrationTest
      test 'creates articles' do
        assert_difference -> { Article.count } do
          post articles_path(format: :json),
            params: { article: { title: 'Ahoy!' } }.to_json,
            headers: { 'Content-Type' => 'application/json' }
        end

        assert_equal({ 'id' => Article.last.id, 'title' => 'Ahoy!' }, JSON.parse(response.body))
      end
    end
    ```

    Can now be written as:

    ```ruby
    require 'test_helper'

    class ApiTest < ActionDispatch::IntegrationTest
      test 'creates articles' do
        assert_difference -> { Article.count } do
          post articles_path, params: { article: { title: 'Ahoy!' } }, as: :json
        end

        assert_equal({ 'id' => Article.last.id, 'title' => 'Ahoy!' }, response.parsed_body)
      end
    end
    ```

    Passing `as: :json` to integration test request helpers will set the format,
    content type and encode the parameters as JSON.

    Then on the response side, `parsed_body` will parse the body according to the
    content type the response has.

    Currently JSON is the only supported MIME type. Add your own with
    `ActionDispatch::IntegrationTest.register_encoder`.

    *Kasper Timm Hansen*

*   Add "image/svg+xml" as a default mime type.

    *DHH*

*   Add `-g` and `-c` options to `bin/rails routes`. These options return the url `name`, `verb` and
    `path` field that match the pattern or match a specific controller.

    Deprecate `CONTROLLER` env variable in `bin/rails routes`.

    See #18902.

    *Anton Davydov*, *Vipul A M*

*   Response etags to always be weak: Prefixes 'W/' to value returned by
   `ActionDispatch::Http::Cache::Response#etag=`, such that etags set in
   `fresh_when` and `stale?` are weak.

    Fixes #17556.

    *Abhishek Yadav*

*   Provide the name of HTTP Status code in assertions.

    *Sean Collins*

*   More explicit error message when running `rake routes`. `CONTROLLER` argument
    can now be supplied in different ways:
    `Rails::WelcomeController`, `Rails::Welcome`, `rails/welcome`.

    Fixes #22918.

    *Edouard Chin*

*   Allow `ActionController::Parameters` instances as an argument to URL
    helper methods. An `ArgumentError` will be raised if the passed parameters
    are not secure.

    Fixes #22832.

    *Prathamesh Sonpatki*

*   Add option for per-form CSRF tokens.

    *Greg Ose*, *Ben Toews*

*   Fix `ActionController::Parameters#convert_parameters_to_hashes` to return filtered
    or unfiltered values based on from where it is called, `to_h` or `to_unsafe_h`
    respectively.

    Fixes #22841.

    *Prathamesh Sonpatki*

*   Add `ActionController::Parameters#include?`

    *Justin Coyne*

*   Deprecate `redirect_to :back` in favor of `redirect_back`, which accepts a
    required `fallback_location` argument, thus eliminating the possibility of a
    `RedirectBackError`.

    *Derek Prior*

*   Add `redirect_back` method to `ActionController::Redirecting` to provide a
    way to safely redirect to the `HTTP_REFERER` if it is present, falling back
    to a provided redirect otherwise.

    *Derek Prior*

*   `ActionController::TestCase` will be moved to its own gem in Rails 5.1.

    With the speed improvements made to `ActionDispatch::IntegrationTest` we no
    longer need to keep two separate code bases for testing controllers. In
    Rails 5.1 `ActionController::TestCase` will be deprecated and moved into a
    gem outside of Rails source.

    This is a documentation deprecation so that going forward new tests will use
    `ActionDispatch::IntegrationTest` instead of `ActionController::TestCase`.

    *Eileen M. Uchitelle*

*   Add a `response_format` option to `ActionDispatch::DebugExceptions`
    to configure the format of the response when errors occur in
    development mode.

    If `response_format` is `:default` the debug info will be rendered
    in an HTML page. In the other hand, if the provided value is `:api`
    the debug info will be rendered in the original response format.

    *Jorge Bejar*

*   Change the `protect_from_forgery` prepend default to `false`.

    Per this comment
    https://github.com/rails/rails/pull/18334#issuecomment-69234050 we want
    `protect_from_forgery` to default to `prepend: false`.

    `protect_from_forgery` will now be inserted into the callback chain at the
    point it is called in your application. This is useful for cases where you
    want to `protect_from_forgery` after you perform required authentication
    callbacks or other callbacks that are required to run after forgery protection.

    If you want `protect_from_forgery` callbacks to always run first, regardless of
    position they are called in your application then you can add `prepend: true`
    to your `protect_from_forgery` call.

    Example:

    ```ruby
    protect_from_forgery prepend: true
    ```

    *Eileen M. Uchitelle*

*   In url_for, never append a question mark to the URL when the query string
    is empty anyway.  (It used to do that when called like `url_for(controller:
    'x', action: 'y', q: {})`.)

    *Paul Grayson*

*   Catch invalid UTF-8 querystring values and respond with BadRequest

    Check querystring params for invalid UTF-8 characters, and raise an
    ActionController::BadRequest error if present. Previously these strings
    would typically trigger errors further down the stack.

    *Grey Baker*

*   Parse RSS/ATOM responses as XML, not HTML.

    *Alexander Kaupanin*

*   Show helpful message in `BadRequest` exceptions due to invalid path
    parameter encodings.

    Fixes #21923.

    *Agis Anastasopoulos*

*   Add the ability of returning arbitrary headers to `ActionDispatch::Static`.

    Now ActionDispatch::Static can accept HTTP headers so that developers
    will have control of returning arbitrary headers like
    'Access-Control-Allow-Origin' when a response is delivered. They can be
    configured with `#config`:

    Example:

        config.public_file_server.headers = {
          "Cache-Control"               => "public, max-age=60",
          "Access-Control-Allow-Origin" => "http://rubyonrails.org"
        }

    *Yuki Nishijima*

*   Allow multiple `root` routes in same scope level. Example:

    Example:

        root 'blog#show', constraints: ->(req) { Hostname.blog_site?(req.host) }
        root 'landing#show'

    *Rafael Sales*

*   Fix regression in mounted engine named routes generation for app deployed to
    a subdirectory. `relative_url_root` was prepended to the path twice (e.g.
    "/subdir/subdir/engine_path" instead of "/subdir/engine_path")

    Fixes #20920. Fixes #21459.

    *Matthew Erhard*

*   `ActionDispatch::Response#new` no longer applies default headers. If you want
    default headers applied to the response object, then call
    `ActionDispatch::Response.create`. This change only impacts people who are
    directly constructing an `ActionDispatch::Response` object.

*   Accessing mime types via constants like `Mime::HTML` is deprecated. Please
    change code like this:

        Mime::HTML

    To this:

        Mime[:html]

    This change is so that Rails will not manage a list of constants, and fixes
    an issue where if a type isn't registered you could possibly get the wrong
    object.

    `Mime[:html]` is available in older versions of Rails, too, so you can
    safely change libraries and plugins and maintain compatibility with
    multiple versions of Rails.

*   `url_for` does not modify its arguments when generating polymorphic URLs.

    *Bernerd Schaefer*

*   Make it easier to opt in to `config.force_ssl` and `config.ssl_options` by
    making them less dangerous to try and easier to disable.

    SSL redirect:
      * Move `:host` and `:port` options within `redirect: { … }`. Deprecate.
      * Introduce `:status` and `:body` to customize the redirect response.
        The 301 permanent default makes it difficult to test the redirect and
        back out of it since browsers remember the 301. Test with a 302 or 307
        instead, then switch to 301 once you're confident that all is well.

    HTTP Strict Transport Security (HSTS):
      * Shorter max-age. Shorten the default max-age from 1 year to 180 days,
        the low end for https://www.ssllabs.com/ssltest/ grading and greater
        than the 18-week minimum to qualify for browser preload lists.
      * Disabling HSTS. Setting `hsts: false` now sets `hsts { expires: 0 }`
        instead of omitting the header. Omitting does nothing to disable HSTS
        since browsers hang on to your previous settings until they expire.
        Sending `{ hsts: { expires: 0 }}` flushes out old browser settings and
        actually disables HSTS:
          http://tools.ietf.org/html/rfc6797#section-6.1.1
      * HSTS Preload. Introduce `preload: true` to set the `preload` flag,
        indicating that your site may be included in browser preload lists,
        including Chrome, Firefox, Safari, IE11, and Edge. Submit your site:
          https://hstspreload.appspot.com

    *Jeremy Daer*

*   Update `ActionController::TestSession#fetch` to behave more like
    `ActionDispatch::Request::Session#fetch` when using non-string keys.

    *Jeremy Friesen*

*   Using strings or symbols for middleware class names is deprecated. Convert
    things like this:

      middleware.use "Foo::Bar"

    to this:

      middleware.use Foo::Bar

*   `ActionController::TestSession` now accepts a default value as well as
    a block for generating a default value based off the key provided.

    This fixes calls to `session#fetch` in `ApplicationController` instances that
    take more two arguments or a block from raising `ArgumentError: wrong
    number of arguments (2 for 1)` when performing controller tests.

    *Matthew Gerrior*

*   Fix `ActionController::Parameters#fetch` overwriting `KeyError` returned by
    default block.

    *Jonas Schuber Erlandsson*, *Roque Pinel*

*   `ActionController::Parameters` no longer inherits from
    `HashWithIndifferentAccess`

    Inheriting from `HashWithIndifferentAccess` allowed users to call any
    enumerable methods on `Parameters` object, resulting in a risk of losing the
    `permitted?` status or even getting back a pure `Hash` object instead of
    a `Parameters` object with proper sanitization.

    By not inheriting from `HashWithIndifferentAccess`, we are able to make
    sure that all methods that are defined in `Parameters` object will return
    a proper `Parameters` object with a correct `permitted?` flag.

    *Prem Sichanugrist*

*   Replaced `ActiveSupport::Concurrency::Latch` with `Concurrent::CountDownLatch`
    from the concurrent-ruby gem.

    *Jerry D'Antonio*

*   Add ability to filter parameters based on parent keys.

        # matches {credit_card: {code: "xxxx"}}
        # doesn't match {file: { code: "xxxx"}}
        config.filter_parameters += [ "credit_card.code" ]

    See #13897.

    *Guillaume Malette*

*   Deprecate passing first parameter as `Hash` and default status code for `head` method.

    *Mehmet Emin İNAÇ*

*   Adds`Rack::Utils::ParameterTypeError` and `Rack::Utils::InvalidParameterError`
    to the rescue_responses hash in `ExceptionWrapper` (Rack recommends
    integrators serve 400s for both of these).

    *Grey Baker*

*   Add support for API only apps.
    `ActionController::API` is added as a replacement of
    `ActionController::Base` for this kind of applications.

    *Santiago Pastorino*, *Jorge Bejar*

*   Remove `assigns` and `assert_template`. Both methods have been extracted
    into a gem at https://github.com/rails/rails-controller-testing.

    See #18950.

    *Alan Guo Xiang Tan*

*   `FileHandler` and `Static` middleware initializers accept `index` argument
    to configure the directory index file name. Defaults to `index` (as in
    `index.html`).

    See #20017.

    *Eliot Sykes*

*   Deprecate `:nothing` option for `render` method.

    *Mehmet Emin İNAÇ*

*   Fix `rake routes` not showing the right format when
    nesting multiple routes.

    See #18373.

    *Ravil Bayramgalin*

*   Add ability to override default form builder for a controller.

        class AdminController < ApplicationController
          default_form_builder AdminFormBuilder
        end

    *Kevin McPhillips*

*   For actions with no corresponding templates, render `head :no_content`
    instead of raising an error. This allows for slimmer API controller
    methods that simply work, without needing further instructions.

    See #19036.

    *Stephen Bussey*

*   Provide friendlier access to request variants.

        request.variant = :phone
        request.variant.phone?  # true
        request.variant.tablet? # false

        request.variant = [:phone, :tablet]
        request.variant.phone?                  # true
        request.variant.desktop?                # false
        request.variant.any?(:phone, :desktop)  # true
        request.variant.any?(:desktop, :watch)  # false

    *George Claghorn*

*   Fix regression where a gzip file response would have a Content-type,
    even when it was a 304 status code.

    See #19271.

    *Kohei Suzuki*

*   Fix handling of empty `X_FORWARDED_HOST` header in `raw_host_with_port`.

    Previously, an empty `X_FORWARDED_HOST` header would cause
    `Actiondispatch::Http:URL.raw_host_with_port` to return `nil`, causing
    `Actiondispatch::Http:URL.host` to raise a `NoMethodError`.

    *Adam Forsyth*

*   Allow `Bearer` as token-keyword in `Authorization-Header`.

    Additionally to `Token`, the keyword `Bearer` is acceptable as a keyword
    for the auth-token. The `Bearer` keyword is described in the original
    OAuth RFC and used in libraries like Angular-JWT.

    See #19094.

    *Peter Schröder*

*   Drop request class from `RouteSet` constructor.

    If you would like to use a custom request class, please subclass and implement
    the `request_class` method.

    *tenderlove@ruby-lang.org*

*   Fallback to `ENV['RAILS_RELATIVE_URL_ROOT']` in `url_for`.

    Fixed an issue where the `RAILS_RELATIVE_URL_ROOT` environment variable is not
    prepended to the path when `url_for` is called. If `SCRIPT_NAME` (used by Rack)
    is set, it takes precedence.

    Fixes #5122.

    *Yasyf Mohamedali*

*   Partitioning of routes is now done when the routes are being drawn. This
    helps to decrease the time spent filtering the routes during the first request.

    *Guo Xiang Tan*

*   Fix regression in functional tests. Responses should have default headers
    assigned.

    See #18423.

    *Jeremy Kemper*, *Yves Senn*

*   Deprecate `AbstractController#skip_action_callback` in favor of individual skip_callback methods
    (which can be made to raise an error if no callback was removed).

    *Iain Beeston*

*   Alias the `ActionDispatch::Request#uuid` method to `ActionDispatch::Request#request_id`.
    Due to implementation, `config.log_tags = [:request_id]` also works in substitute
    for `config.log_tags = [:uuid]`.

    *David Ilizarov*

*   Change filter on /rails/info/routes to use an actual path regexp from rails
    and not approximate javascript version. Oniguruma supports much more
    extensive list of features than javascript regexp engine.

    Fixes #18402.

    *Ravil Bayramgalin*

*   Non-string authenticity tokens do not raise NoMethodError when decoding
    the masked token.

    *Ville Lautanala*

*   Add `http_cache_forever` to Action Controller, so we can cache a response
    that never gets expired.

    *arthurnn*

*   `ActionController#translate` supports symbols as shortcuts.
    When a shortcut is given it also performs the lookup without the action
    name.

    *Max Melentiev*

*   Expand `ActionController::ConditionalGet#fresh_when` and `stale?` to also
    accept a collection of records as the first argument, so that the
    following code can be written in a shorter form.

        # Before
        def index
          @articles = Article.all
          fresh_when(etag: @articles, last_modified: @articles.maximum(:updated_at))
        end

        # After
        def index
          @articles = Article.all
          fresh_when(@articles)
        end

    *claudiob*

*   Explicitly ignored wildcard verbs when searching for HEAD routes before fallback

    Fixes an issue where a mounted rack app at root would intercept the HEAD
    request causing an incorrect behavior during the fall back to GET requests.

    Example:

        draw do
            get '/home' => 'test#index'
            mount rack_app, at: '/'
        end
        head '/home'
        assert_response :success

    In this case, a HEAD request runs through the routes the first time and fails
    to match anything. Then, it runs through the list with the fallback and matches
    `get '/home'`. The original behavior would match the rack app in the first pass.

    *Terence Sun*

*   Discarded flash messages get removed before storing into session.

    *Samuel Cochran*

*   Migrating xhr methods to keyword arguments syntax
    in `ActionController::TestCase` and `ActionDispatch::Integration`

    Old syntax:

        xhr :get, :create, params: { id: 1 }

    New syntax example:

        get :create, params: { id: 1 }, xhr: true

    *Kir Shatrov*

*   Migrating to keyword arguments syntax in `ActionController::TestCase` and
    `ActionDispatch::Integration` HTTP request methods.

    Example:

        post :create, params: { y: x }, session: { a: 'b' }
        get :view, params: { id: 1 }
        get :view, params: { id: 1 }, format: :json

    *Kir Shatrov*

*   Preserve default url options when generating URLs.

    Fixes an issue that would cause `default_url_options` to be lost when
    generating URLs with fewer positional arguments than parameters in the
    route definition.

    *Tekin Suleyman*

*   Deprecate `*_via_redirect` integration test methods.

    Use `follow_redirect!` manually after the request call for the same behavior.

    *Aditya Kapoor*

*   Add `ActionController::Renderer` to render arbitrary templates
    outside controller actions.

    Its functionality is accessible through class methods `render` and
    `renderer` of `ActionController::Base`.

    *Ravil Bayramgalin*

*   Support `:assigns` option when rendering with controllers/mailers.

    *Ravil Bayramgalin*

*   Default headers, removed in controller actions, are no longer reapplied on
    the test response.

    *Jonas Baumann*

*   Deprecate all `*_filter` callbacks in favor of `*_action` callbacks.

    *Rafael Mendonça França*

*   Allow you to pass `prepend: false` to `protect_from_forgery` to have the
    verification callback appended instead of prepended to the chain.
    This allows you to let the verification step depend on prior callbacks.

    Example:

        class ApplicationController < ActionController::Base
          before_action :authenticate
          protect_from_forgery prepend: false, unless: -> { @authenticated_by.oauth? }

          private
            def authenticate
              if oauth_request?
                # authenticate with oauth
                @authenticated_by = 'oauth'.inquiry
              else
                # authenticate with cookies
                @authenticated_by = 'cookie'.inquiry
              end
            end
        end

    *Josef Šimánek*

*   Remove `ActionController::HideActions`.

    *Ravil Bayramgalin*

*   Remove `respond_to`/`respond_with` placeholder methods, this functionality
    has been extracted to the `responders` gem.

    *Carlos Antonio da Silva*

*   Remove deprecated assertion files.

    *Rafael Mendonça França*

*   Remove deprecated usage of string keys in URL helpers.

    *Rafael Mendonça França*

*   Remove deprecated `only_path` option on `*_path` helpers.

    *Rafael Mendonça França*

*   Remove deprecated `NamedRouteCollection#helpers`.

    *Rafael Mendonça França*

*   Remove deprecated support to define routes with `:to` option that doesn't contain `#`.

    *Rafael Mendonça França*

*   Remove deprecated `ActionDispatch::Response#to_ary`.

    *Rafael Mendonça França*

*   Remove deprecated `ActionDispatch::Request#deep_munge`.

    *Rafael Mendonça França*

*   Remove deprecated `ActionDispatch::Http::Parameters#symbolized_path_parameters`.

    *Rafael Mendonça França*

*   Remove deprecated option `use_route` in controller tests.

    *Rafael Mendonça França*

*   Ensure `append_info_to_payload` is called even if an exception is raised.

    Fixes an issue where when an exception is raised in the request the additional
    payload data is not available.

    See #14903.

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

*   Stop converting empty arrays in `params` to `nil`.

    This behavior was introduced in response to CVE-2012-2660, CVE-2012-2694
    and CVE-2013-0155

    ActiveRecord now issues a safe query when passing an empty array into
    a where clause, so there is no longer a need to defend against this type
    of input (any nils are still stripped from the array).

    *Chris Sinjakli*

*   Remove `ActionController::ModelNaming` module.

    *claudiob*

*   Fixed usage of optional scopes in url helpers.

    *Alex Robbin*

*   Fixed handling of positional url helper arguments when `format: false`.

    Fixes #17819.

    *Andrew White*, *Tatiana Soukiassian*

Please check [4-2-stable](https://github.com/rails/rails/blob/4-2-stable/actionpack/CHANGELOG.md) for previous changes.
