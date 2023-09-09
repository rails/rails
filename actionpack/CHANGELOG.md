## Rails 7.0.8 (September 09, 2023) ##

*   Fix `HostAuthorization` potentially displaying the value of the
    X_FORWARDED_HOST header when the HTTP_HOST header is being blocked.

    *Hartley McGuire*, *Daniel Schlosser*


## Rails 7.0.7.2 (August 22, 2023) ##

*   No changes.


## Rails 7.0.7.1 (August 22, 2023) ##

*   No changes.


## Rails 7.0.7 (August 09, 2023) ##

*   No changes.


## Rails 7.0.6 (June 29, 2023) ##

*   No changes.


## Rails 7.0.5.1 (June 26, 2023) ##

*   Raise an exception if illegal characters are provide to redirect_to
    [CVE-2023-28362]

    *Zack Deveau*

## Rails 7.0.5 (May 24, 2023) ##

*   Do not return CSP headers for 304 Not Modified responses.

    *Tobias Kraze*

*   Fix `EtagWithFlash` when there is no `Flash` middleware available.

    *fatkodima*

*   Fix content-type header with `send_stream`.

    *Elliot Crosby-McCullough*

*   Address Selenium `:capabilities` deprecation warning.

    *Ron Shinall*

*   Fix cookie domain for domain: all on two letter single level TLD.

    *John Hawthorn*

*   Don't double log the `controller`, `action`, or `namespaced_controller` when using `ActiveRecord::QueryLog`

    Previously if you set `config.active_record.query_log_tags` to an array that included
    `:controller`, `:namespaced_controller`, or `:action`, that item would get logged twice.
    This bug has been fixed.

    *Alex Ghiculescu*

*   Rescue `EOFError` exception from `rack` on a multipart request.

    *Nikita Vasilevsky*

*   Rescue `JSON::ParserError` in Cookies json deserializer to discards marshal dumps:

    Without this change, if `action_dispatch.cookies_serializer` is set to `:json` and
    the app tries to read a `:marshal` serialized cookie, it would error out which wouldn't
    clear the cookie and force app users to manually clear it in their browser.

    (See #45127 for original bug discussion)

    *Nathan Bardoux*

## Rails 7.0.4.3 (March 13, 2023) ##

*   No changes.


## Rails 7.0.4.2 (January 24, 2023) ##

*   Fix `domain: :all` for two letter TLD

    This fixes a compatibility issue introduced in our previous security
    release when using `domain: :all` with a two letter but single level top
    level domain domain (like `.ca`, rather than `.co.uk`).


## Rails 7.0.4.1 (January 17, 2023) ##

*   Fix sec issue with _url_host_allowed?

    Disallow certain strings from `_url_host_allowed?` to avoid a redirect
    to malicious sites.

    [CVE-2023-22797]

*   Avoid regex backtracking on If-None-Match header

    [CVE-2023-22795]

*   Use string#split instead of regex for domain parts

    [CVE-2023-22792]

## Rails 7.0.4 (September 09, 2022) ##

*   Prevent `ActionDispatch::ServerTiming` from overwriting existing values in `Server-Timing`.

    Previously, if another middleware down the chain set `Server-Timing` header,
    it would overwritten by `ActionDispatch::ServerTiming`.

    *Jakub Malinowski*


## Rails 7.0.3.1 (July 12, 2022) ##

*   No changes.


## Rails 7.0.3 (May 09, 2022) ##

*   Allow relative redirects when `raise_on_open_redirects` is enabled.

    *Tom Hughes*

*   Fix `authenticate_with_http_basic` to allow for missing password.

    Before Rails 7.0 it was possible to handle basic authentication with only a username.

    ```ruby
    authenticate_with_http_basic do |token, _|
      ApiClient.authenticate(token)
    end
    ```

    This ability is restored.

    *Jean Boussier*

*   Fix `content_security_policy` returning invalid directives.

    Directives such as `self`, `unsafe-eval` and few others were not
    single quoted when the directive was the result of calling a lambda
    returning an array.

    ```ruby
    content_security_policy do |policy|
      policy.frame_ancestors lambda { [:self, "https://example.com"] }
    end
    ```

    With this fix the policy generated from above will now be valid.

    *Edouard Chin*

*   Fix `skip_forgery_protection` to run without raising an error if forgery
    protection has not been enabled / `verify_authenticity_token` is not a
    defined callback.

    This fix prevents the Rails 7.0 Welcome Page (`/`) from raising an
    `ArgumentError` if `default_protect_from_forgery` is false.

    *Brad Trick*

*   Fix `ActionController::Live` to copy the IsolatedExecutionState in the ephemeral thread.

    Since its inception `ActionController::Live` has been copying thread local variables
    to keep things such as `CurrentAttributes` set from middlewares working in the controller action.

    With the introduction of `IsolatedExecutionState` in 7.0, some of that global state was lost in
    `ActionController::Live` controllers.

    *Jean Boussier*

*   Fix setting `trailing_slash: true` in route definition.

    ```ruby
    get '/test' => "test#index", as: :test, trailing_slash: true

    test_path() # => "/test/"
    ```

    *Jean Boussier*

## Rails 7.0.2.4 (April 26, 2022) ##

*   Allow Content Security Policy DSL to generate for API responses.

    *Tim Wade*

## Rails 7.0.2.3 (March 08, 2022) ##

*   No changes.


## Rails 7.0.2.2 (February 11, 2022) ##

*   No changes.


## Rails 7.0.2.1 (February 11, 2022) ##

*   Under certain circumstances, the middleware isn't informed that the
    response body has been fully closed which result in request state not
    being fully reset before the next request

    [CVE-2022-23633]


## Rails 7.0.2 (February 08, 2022) ##

*   No changes.


## Rails 7.0.1 (January 06, 2022) ##

*   Fix `ActionController::Parameters` methods to keep the original logger context when creating a new copy
    of the original object.

    *Yutaka Kamei*


## Rails 7.0.0 (December 15, 2021) ##

*   Deprecate `Rails.application.config.action_controller.urlsafe_csrf_tokens`. This config is now always enabled.

    *Étienne Barrié*

*   Instance variables set in requests in a `ActionController::TestCase` are now cleared before the next request

    This means if you make multiple requests in the same test, instance variables set in the first request will
    not persist into the second one. (It's not recommended to make multiple requests in the same test.)

    *Alex Ghiculescu*


## Rails 7.0.0.rc3 (December 14, 2021) ##

*   No changes.


## Rails 7.0.0.rc2 (December 14, 2021) ##

*   Fix X_FORWARDED_HOST protection.  [CVE-2021-44528]


## Rails 7.0.0.rc1 (December 06, 2021) ##

*   `Rails.application.executor` hooks can now be called around every request in a `ActionController::TestCase`

    This helps to better simulate request or job local state being reset between requests and prevent state
    leaking from one request to another.

    To enable this, set `config.active_support.executor_around_test_case = true` (this is the default in Rails 7).

    *Alex Ghiculescu*

*   Consider onion services secure for cookies.

    *Justin Tracey*

*   Remove deprecated `Rails.config.action_view.raise_on_missing_translations`.

    *Rafael Mendonça França*

*   Remove deprecated support to passing a path to `fixture_file_upload` relative to `fixture_path`.

    *Rafael Mendonça França*

*   Remove deprecated `ActionDispatch::SystemTestCase#host!`.

    *Rafael Mendonça França*

*   Remove deprecated `Rails.config.action_dispatch.hosts_response_app`.

    *Rafael Mendonça França*

*   Remove deprecated `ActionDispatch::Response.return_only_media_type_on_content_type`.

    *Rafael Mendonça França*

*   Raise `ActionController::Redirecting::UnsafeRedirectError` for unsafe `redirect_to` redirects.

    This allows `rescue_from` to be used to add a default fallback route:

    ```ruby
    rescue_from ActionController::Redirecting::UnsafeRedirectError do
      redirect_to root_url
    end
    ```

    *Kasper Timm Hansen*, *Chris Oliver*

*   Add `url_from` to verify a redirect location is internal.

    Takes the open redirect protection from `redirect_to` so users can wrap a
    param, and fall back to an alternate redirect URL when the param provided
    one is unsafe.

    ```ruby
    def create
      redirect_to url_from(params[:redirect_url]) || root_url
    end
    ```

    *dmcge*, *Kasper Timm Hansen*

*   Allow Capybara driver name overrides in `SystemTestCase::driven_by`

    Allow users to prevent conflicts among drivers that use the same driver
    type (selenium, poltergeist, webkit, rack test).

    Fixes #42502

    *Chris LaRose*

*   Allow multiline to be passed in routes when using wildcard segments.

    Previously routes with newlines weren't detected when using wildcard segments, returning
    a `No route matches` error.
    After this change, routes with newlines are detected on wildcard segments. Example

    ```ruby
      draw do
        get "/wildcard/*wildcard_segment", to: SimpleApp.new("foo#index"), as: :wildcard
      end

      # After the change, the path matches.
      assert_equal "/wildcard/a%0Anewline", url_helpers.wildcard_path(wildcard_segment: "a\nnewline")
    ```

    Fixes #39103

    *Ignacio Chiazzo*

*   Treat html suffix in controller translation.

    *Rui Onodera*, *Gavin Miller*

*   Allow permitting numeric params.

    Previously it was impossible to permit different fields on numeric parameters.
    After this change you can specify different fields for each numbered parameter.
    For example params like,
    ```ruby
    book: {
            authors_attributes: {
              '0': { name: "William Shakespeare", age_of_death: "52" },
              '1': { name: "Unattributed Assistant" },
              '2': "Not a hash",
              'new_record': { name: "Some name" }
            }
          }
    ```

    Before you could permit name on each author with,
    `permit book: { authors_attributes: [ :name ] }`

    After this change you can permit different keys on each numbered element,
    `permit book: { authors_attributes: { '1': [ :name ], '0': [ :name, :age_of_death ] } }`

    Fixes #41625

    *Adam Hess*

*   Update `HostAuthorization` middleware to render debug info only
    when `config.consider_all_requests_local` is set to true.

    Also, blocked host info is always logged with level `error`.

    Fixes #42813

    *Nikita Vyrko*

*  Add Server-Timing middleware

   Server-Timing specification defines how the server can communicate to browsers performance metrics
   about the request it is responding to.

   The ServerTiming middleware is enabled by default on `development` environment by default using the
   `config.server_timing` setting and set the relevant duration metrics in the `Server-Timing` header

   The full specification for Server-Timing header can be found in: https://www.w3.org/TR/server-timing/#dfn-server-timing-header-field

   *Sebastian Sogamoso*, *Guillermo Iguaran*


## Rails 7.0.0.alpha2 (September 15, 2021) ##

*   No changes.


## Rails 7.0.0.alpha1 (September 15, 2021) ##

*   Use a static error message when raising `ActionDispatch::Http::Parameters::ParseError`
    to avoid inadvertently logging the HTTP request body at the `fatal` level when it contains
    malformed JSON.

    Fixes #41145

    *Aaron Lahey*

*   Add `Middleware#delete!` to delete middleware or raise if not found.

    `Middleware#delete!` works just like `Middleware#delete` but will
    raise an error if the middleware isn't found.

    *Alex Ghiculescu*, *Petrik de Heus*, *Junichi Sato*

*   Raise error on unpermitted open redirects.

    Add `allow_other_host` options to `redirect_to`.
    Opt in to this behaviour with `ActionController::Base.raise_on_open_redirects = true`.

    *Gannon McGibbon*

*   Deprecate `poltergeist` and `webkit` (capybara-webkit) driver registration for system testing (they will be removed in Rails 7.1). Add `cuprite` instead.

    [Poltergeist](https://github.com/teampoltergeist/poltergeist) and [capybara-webkit](https://github.com/thoughtbot/capybara-webkit) are already not maintained. These usage in Rails are removed for avoiding confusing users.

    [Cuprite](https://github.com/rubycdp/cuprite) is a good alternative to Poltergeist. Some guide descriptions are replaced from Poltergeist to Cuprite.

    *Yusuke Iwaki*

*   Exclude additional flash types from `ActionController::Base.action_methods`.

    Ensures that additional flash types defined on ActionController::Base subclasses
    are not listed as actions on that controller.

        class MyController < ApplicationController
          add_flash_types :hype
        end

        MyController.action_methods.include?('hype') # => false

    *Gavin Morrice*

*   OpenSSL constants are now used for Digest computations.

    *Dirkjan Bussink*

*   Remove IE6-7-8 file download related hack/fix from ActionController::DataStreaming module.

    Due to the age of those versions of IE this fix is no longer relevant, more importantly it creates an edge-case for unexpected Cache-Control headers.

    *Tadas Sasnauskas*

*   Configuration setting to skip logging an uncaught exception backtrace when the exception is
    present in `rescued_responses`.

    It may be too noisy to get all backtraces logged for applications that manage uncaught
    exceptions via `rescued_responses` and `exceptions_app`.
    `config.action_dispatch.log_rescued_responses` (defaults to `true`) can be set to `false` in
    this case, so that only exceptions not found in `rescued_responses` will be logged.

    *Alexander Azarov*, *Mike Dalessio*

*   Ignore file fixtures on `db:fixtures:load`.

    *Kevin Sjöberg*

*   Fix ActionController::Live controller test deadlocks by removing the body buffer size limit for tests.

    *Dylan Thacker-Smith*

*   New `ActionController::ConditionalGet#no_store` method to set HTTP cache control `no-store` directive.

    *Tadas Sasnauskas*

*   Drop support for the `SERVER_ADDR` header.

    Following up https://github.com/rack/rack/pull/1573 and https://github.com/rails/rails/pull/42349.

    *Ricardo Díaz*

*   Set session options when initializing a basic session.

    *Gannon McGibbon*

*   Add `cache_control: {}` option to `fresh_when` and `stale?`.

    Works as a shortcut to set `response.cache_control` with the above methods.

    *Jacopo Beschi*

*   Writing into a disabled session will now raise an error.

    Previously when no session store was set, writing into the session would silently fail.

    *Jean Boussier*

*   Add support for 'require-trusted-types-for' and 'trusted-types' headers.

    Fixes #42034.

    *lfalcao*

*   Remove inline styles and address basic accessibility issues on rescue templates.

    *Jacob Herrington*

*   Add support for 'private, no-store' Cache-Control headers.

    Previously, 'no-store' was exclusive; no other directives could be specified.

    *Alex Smith*

*   Expand payload of `unpermitted_parameters.action_controller` instrumentation to allow subscribers to
    know which controller action received unpermitted parameters.

    *bbuchalter*

*   Add `ActionController::Live#send_stream` that makes it more convenient to send generated streams:

    ```ruby
    send_stream(filename: "subscribers.csv") do |stream|
      stream.writeln "email_address,updated_at"

      @subscribers.find_each do |subscriber|
        stream.writeln [ subscriber.email_address, subscriber.updated_at ].join(",")
      end
    end
    ```

    *DHH*

*   Add `ActionController::Live::Buffer#writeln` to write a line to the stream with a newline included.

    *DHH*

*   `ActionDispatch::Request#content_type` now returned Content-Type header as it is.

    Previously, `ActionDispatch::Request#content_type` returned value does NOT contain charset part.
    This behavior changed to returned Content-Type header containing charset part as it is.

    If you want just MIME type, please use `ActionDispatch::Request#media_type` instead.

    Before:

    ```ruby
    request = ActionDispatch::Request.new("CONTENT_TYPE" => "text/csv; header=present; charset=utf-16", "REQUEST_METHOD" => "GET")
    request.content_type #=> "text/csv"
    ```

    After:

    ```ruby
    request = ActionDispatch::Request.new("Content-Type" => "text/csv; header=present; charset=utf-16", "REQUEST_METHOD" => "GET")
    request.content_type #=> "text/csv; header=present; charset=utf-16"
    request.media_type   #=> "text/csv"
    ```

    *Rafael Mendonça França*

*   Change `ActionDispatch::Request#media_type` to return `nil` when the request don't have a `Content-Type` header.

    *Rafael Mendonça França*

*   Fix error in `ActionController::LogSubscriber` that would happen when throwing inside a controller action.

    *Janko Marohnić*

*   Allow anything with `#to_str` (like `Addressable::URI`) as a `redirect_to` location.

    *ojab*

*   Change the request method to a `GET` when passing failed requests down to `config.exceptions_app`.

    *Alex Robbin*

*   Deprecate the ability to assign a single value to `config.action_dispatch.trusted_proxies`
    as `RemoteIp` middleware behaves inconsistently depending on whether this is configured
    with a single value or an enumerable.

    Fixes #40772.

    *Christian Sutter*

*   Add `redirect_back_or_to(fallback_location, **)` as a more aesthetically pleasing version of `redirect_back fallback_location:, **`.
    The old method name is retained without explicit deprecation.

    *DHH*


Please check [6-1-stable](https://github.com/rails/rails/blob/6-1-stable/actionpack/CHANGELOG.md) for previous changes.
