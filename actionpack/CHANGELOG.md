*   Signed and encrypted cookies can now store `false` as their value when
    `action_dispatch.use_cookies_with_metadata` is enabled.

    *Rolandas Barysas*


## Rails 6.0.3.6 (March 26, 2021) ##

*   No changes.


## Rails 6.0.3.5 (February 10, 2021) ##

*   Prevent open redirect when allowed host starts with a dot

    [CVE-2021-22881]

    Thanks to @tktech (https://hackerone.com/tktech) for reporting this
    issue and the patch!

    *Aaron Patterson*


## Rails 6.0.3.4 (October 07, 2020) ##

*   [CVE-2020-8264] Prevent XSS in Actionable Exceptions


## Rails 6.0.3.3 (September 09, 2020) ##

*   No changes.


## Rails 6.0.3.2 (June 17, 2020) ##

*   [CVE-2020-8185] Only allow ActionableErrors if show_detailed_exceptions is enabled

## Rails 6.0.3.1 (May 18, 2020) ##

*   [CVE-2020-8166] HMAC raw CSRF token before masking it, so it cannot be used to reconstruct a per-form token

*   [CVE-2020-8164] Return self when calling #each, #each_pair, and #each_value instead of the raw @parameters hash


## Rails 6.0.3 (May 06, 2020) ##

*   Include child session assertion count in ActionDispatch::IntegrationTest

    `IntegrationTest#open_session` uses `dup` to create the new session, which
    meant it had its own copy of `@assertions`. This prevented the assertions
    from being correctly counted and reported.

    Child sessions now have their `attr_accessor` overriden to delegate to the
    root session.

    Fixes #32142

    *Sam Bostock*


## Rails 6.0.2.2 (March 19, 2020) ##

*   No changes.


## Rails 6.0.2.1 (December 18, 2019) ##

*   Fix possible information leak / session hijacking vulnerability.

    The `ActionDispatch::Session::MemcacheStore` is still vulnerable given it requires the
    gem dalli to be updated as well.

    CVE-2019-16782.


## Rails 6.0.2 (December 13, 2019) ##

*   Allow using mountable engine route helpers in System Tests.

    *Chalo Fernandez*


## Rails 6.0.1 (November 5, 2019) ##

*   `ActionDispatch::SystemTestCase` now inherits from `ActiveSupport::TestCase`
    rather than `ActionDispatch::IntegrationTest`. This permits running jobs in
    system tests.

    *George Claghorn*, *Edouard Chin*

*   Registered MIME types may contain extra flags:

    ```ruby
    Mime::Type.register "text/html; fragment", :html_fragment
    ```

    *Aaron Patterson*


## Rails 6.0.0 (August 16, 2019) ##

*   No changes.


## Rails 6.0.0.rc2 (July 22, 2019) ##

*   Add the ability to set the CSP nonce only to the specified directives.

    Fixes #35137.

    *Yuji Yaginuma*

*   Keep part when scope option has value.

    When a route was defined within an optional scope, if that route didn't
    take parameters the scope was lost when using path helpers. This commit
    ensures scope is kept both when the route takes parameters or when it
    doesn't.

    Fixes #33219

    *Alberto Almagro*

*   Change `ActionDispatch::Response#content_type` to return Content-Type header as it is.

    Previously, `ActionDispatch::Response#content_type` returned value does NOT
    contain charset part. This behavior changed to returned Content-Type header
    containing charset part as it is.

    If you want just MIME type, please use `ActionDispatch::Response#media_type`
    instead.

    Enable `action_dispatch.return_only_media_type_on_content_type` to use this change.
    If not enabled, `ActionDispatch::Response#content_type` returns the same
    value as before version, but its behavior is deprecate.

    *Yuji Yaginuma*

*   Calling `ActionController::Parameters#transform_keys/!` without a block now returns
    an enumerator for the parameters instead of the underlying hash.

    *Eugene Kenny*

*   Fix a bug where DebugExceptions throws an error when malformed query parameters are provided

    *Yuki Nishijima*, *Stan Lo*


## Rails 6.0.0.rc1 (April 24, 2019) ##

*   Make system tests take a failed screenshot in a `before_teardown` hook
    rather than an `after_teardown` hook.

    This helps minimize the time gap between when an assertion fails and when
    the screenshot is taken (reducing the time in which the page could have
    been dynamically updated after the assertion failed).

    *Richard Macklin*

*   Introduce `ActionDispatch::ActionableExceptions`.

    The `ActionDispatch::ActionableExceptions` middleware dispatches actions
    from `ActiveSupport::ActionableError` descendants.

    Actionable errors let's you dispatch actions from Rails' error pages.

    *Vipul A M*, *Yao Jie*, *Genadi Samokovarov*

*   Raise an `ArgumentError` if a resource custom param contains a colon (`:`).

    After this change it's not possible anymore to configure routes like this:

    ```
    routes.draw do
      resources :users, param: 'name/:sneaky'
    end
    ```

    Fixes #30467.

    *Josua Schmid*


## Rails 6.0.0.beta3 (March 11, 2019) ##

*   No changes.


## Rails 6.0.0.beta2 (February 25, 2019) ##

*   Make debug exceptions works in an environment where ActiveStorage is not loaded.

    *Tomoyuki Kurosawa*

*   `ActionDispatch::SystemTestCase.driven_by` can now be called with a block
    to define specific browser capabilities.

    *Edouard Chin*


## Rails 6.0.0.beta1 (January 18, 2019) ##

*   Remove deprecated `fragment_cache_key` helper in favor of `combined_fragment_cache_key`.

    *Rafael Mendonça França*

*   Remove deprecated methods in `ActionDispatch::TestResponse`.

    `#success?`, `missing?` and `error?` were deprecated in Rails 5.2 in favor of
    `#successful?`, `not_found?` and `server_error?`.

    *Rafael Mendonça França*

*   Introduce `ActionDispatch::HostAuthorization`.

    This is a new middleware that guards against DNS rebinding attacks by
    explicitly permitting the hosts a request can be made to.

    Each host is checked with the case operator (`#===`) to support `Regexp`,
    `Proc`, `IPAddr` and custom objects as host allowances.

    *Genadi Samokovarov*

*   Allow using `parsed_body` in `ActionController::TestCase`.

    In addition to `ActionDispatch::IntegrationTest`, allow using
    `parsed_body` in `ActionController::TestCase`:

    ```
    class SomeControllerTest < ActionController::TestCase
      def test_some_action
        post :action, body: { foo: 'bar' }
        assert_equal({ "foo" => "bar" }, response.parsed_body)
      end
    end
    ```

    Fixes #34676.

    *Tobias Bühlmann*

*   Raise an error on root route naming conflicts.

    Raises an `ArgumentError` when multiple root routes are defined in the
    same context instead of assigning nil names to subsequent roots.

    *Gannon McGibbon*

*   Allow rescue from parameter parse errors:

    ```
    rescue_from ActionDispatch::Http::Parameters::ParseError do
      head :unauthorized
    end
    ```

    *Gannon McGibbon*, *Josh Cheek*

*   Reset Capybara sessions if failed system test screenshot raising an exception.

    Reset Capybara sessions if `take_failed_screenshot` raise exception
    in system test `after_teardown`.

    *Maxim Perepelitsa*

*   Use request object for context if there's no controller

    There is no controller instance when using a redirect route or a
    mounted rack application so pass the request object as the context
    when resolving dynamic CSP sources in this scenario.

    Fixes #34200.

    *Andrew White*

*   Apply mapping to symbols returned from dynamic CSP sources

    Previously if a dynamic source returned a symbol such as :self it
    would be converted to a string implicitly, e.g:

        policy.default_src -> { :self }

    would generate the header:

        Content-Security-Policy: default-src self

    and now it generates:

        Content-Security-Policy: default-src 'self'

    *Andrew White*

*   Add `ActionController::Parameters#each_value`.

    *Lukáš Zapletal*

*   Deprecate `ActionDispatch::Http::ParameterFilter` in favor of `ActiveSupport::ParameterFilter`.

    *Yoshiyuki Kinjo*

*   Encode Content-Disposition filenames on `send_data` and `send_file`.
    Previously, `send_data 'data', filename: "\u{3042}.txt"` sends
    `"filename=\"\u{3042}.txt\""` as Content-Disposition and it can be
    garbled.
    Now it follows [RFC 2231](https://tools.ietf.org/html/rfc2231) and
    [RFC 5987](https://tools.ietf.org/html/rfc5987) and sends
    `"filename=\"%3F.txt\"; filename*=UTF-8''%E3%81%82.txt"`.
    Most browsers can find filename correctly and old browsers fallback to ASCII
    converted name.

    *Fumiaki Matsushima*

*   Expose `ActionController::Parameters#each_key` which allows iterating over
    keys without allocating an array.

    *Richard Schneeman*

*   Purpose metadata for signed/encrypted cookies.

    Rails can now thwart attacks that attempt to copy signed/encrypted value
    of a cookie and use it as the value of another cookie.

    It does so by stashing the cookie-name in the purpose field which is
    then signed/encrypted along with the cookie value. Then, on a server-side
    read, we verify the cookie-names and discard any attacked cookies.

    Enable `action_dispatch.use_cookies_with_metadata` to use this feature, which
    writes cookies with the new purpose and expiry metadata embedded.

    *Assain Jaleel*

*   Raises `ActionController::RespondToMismatchError` with conflicting `respond_to` invocations.

    `respond_to` can match multiple types and lead to undefined behavior when
    multiple invocations are made and the types do not match:

        respond_to do |outer_type|
          outer_type.js do
            respond_to do |inner_type|
              inner_type.html { render body: "HTML" }
            end
          end
        end

    *Patrick Toomey*

*   `ActionDispatch::Http::UploadedFile` now delegates `to_path` to its tempfile.

    This allows uploaded file objects to be passed directly to `File.read`
    without raising a `TypeError`:

        uploaded_file = ActionDispatch::Http::UploadedFile.new(tempfile: tmp_file)
        File.read(uploaded_file)

    *Aaron Kromer*

*   Pass along arguments to underlying `get` method in `follow_redirect!`

    Now all arguments passed to `follow_redirect!` are passed to the underlying
    `get` method. This for example allows to set custom headers for the
    redirection request to the server.

        follow_redirect!(params: { foo: :bar })

    *Remo Fritzsche*

*   Introduce a new error page to when the implicit render page is accessed in the browser.

    Now instead of showing an error page that with exception and backtraces we now show only
    one informative page.

    *Vinicius Stock*

*   Introduce `ActionDispatch::DebugExceptions.register_interceptor`.

    Exception aware plugin authors can use the newly introduced
    `.register_interceptor` method to get the processed exception, instead of
    monkey patching DebugExceptions.

        ActionDispatch::DebugExceptions.register_interceptor do |request, exception|
          HypoteticalPlugin.capture_exception(request, exception)
        end

    *Genadi Samokovarov*

*   Output only one Content-Security-Policy nonce header value per request.

    Fixes #32597.

    *Andrey Novikov*, *Andrew White*

*   Move default headers configuration into their own module that can be included in controllers.

    *Kevin Deisz*

*   Add method `dig` to `session`.

    *claudiob*, *Takumi Shotoku*

*   Controller level `force_ssl` has been deprecated in favor of
    `config.force_ssl`.

    *Derek Prior*

*   Rails 6 requires Ruby 2.5.0 or newer.

    *Jeremy Daer*, *Kasper Timm Hansen*


Please check [5-2-stable](https://github.com/rails/rails/blob/5-2-stable/actionpack/CHANGELOG.md) for previous changes.
