*   Remove leading dot from domains on cookies set with `domain: :all`, to meet RFC6265 requirements

    *Gareth Adams*

*   Include source location in routes extended view.

    ```bash
    $ bin/rails routes --expanded

    ...
    --[ Route 14 ]----------
    Prefix            | new_gist
    Verb              | GET
    URI               | /gist(.:format)
    Controller#Action | gists/gists#new
    Source Location   | config/routes/gist.rb:3
    ```

    *Luan Vieira, John Hawthorn and Daniel Colson*

*   Add `without` as an alias of `except` on `ActiveController::Parameters`.

    *Hidde-Jan Jongsma*

*   Expand search field on `rails/info/routes` to also search **route name**, **http verb** and **controller#action**.

    *Jason Kotchoff*

*   Remove deprecated `poltergeist` and `webkit` (capybara-webkit) driver registration for system testing.

    *Rafael Mendonça França*

*   Remove deprecated ability to assign a single value to `config.action_dispatch.trusted_proxies`.

    *Rafael Mendonça França*

*   Deprecate `config.action_dispatch.return_only_request_media_type_on_content_type`.

    *Rafael Mendonça França*

*   Remove deprecated behavior on `Request#content_type`.

    *Rafael Mendonça França*

*   Change `ActionController::Instrumentation` to pass `filtered_path` instead of `fullpath` in the event payload to filter sensitive query params

    ```ruby
    get "/posts?password=test"
    request.fullpath         # => "/posts?password=test"
    request.filtered_path    # => "/posts?password=[FILTERED]"
    ```

    *Ritikesh G*

*   Deprecate `AbstractController::Helpers::MissingHelperError`

    *Hartley McGuire*

*   Change `ActionDispatch::Testing::TestResponse#parsed_body` to parse HTML as
    a Nokogiri document

    ```ruby
    get "/posts"
    response.content_type         # => "text/html; charset=utf-8"
    response.parsed_body.class    # => Nokogiri::HTML5::Document
    response.parsed_body.to_html  # => "<!DOCTYPE html>\n<html>\n..."
    ```

    *Sean Doyle*

*   Deprecate `ActionDispatch::IllegalStateError`.

    *Samuel Williams*

*   Add HTTP::Request#route_uri_pattern that returns URI pattern of matched route.

    *Joel Hawksley*, *Kate Higa*

*   Add `ActionDispatch::AssumeSSL` middleware that can be turned on via `config.assume_ssl`.
    It makes the application believe that all requests are arriving over SSL. This is useful
    when proxying through a load balancer that terminates SSL, the forwarded request will appear
    as though its HTTP instead of HTTPS to the application. This makes redirects and cookie
    security target HTTP instead of HTTPS. This middleware makes the server assume that the
    proxy already terminated SSL, and that the request really is HTTPS.

    *DHH*

*   Only use HostAuthorization middleware if `config.hosts` is not empty

    *Hartley McGuire*

*   Allow raising an error when a callback's only/unless symbols aren't existing methods.

    When `before_action :callback, only: :action_name` is declared on a controller that doesn't respond to `action_name`, raise an exception at request time. This is a safety measure to ensure that typos or forgetfulness don't prevent a crucial callback from being run when it should.

    For new applications, raising an error for undefined actions is turned on by default. If you do not want to opt-in to this behavior set `config.action_pack.raise_on_missing_callback_actions` to `false` in your application configuration. See #43487 for more details.

    *Jess Bees*

*   Allow cookie options[:domain] to accept a proc to set the cookie domain on a more flexible per-request basis

    *RobL*

*   When a host is not specified for an `ActionController::Renderer`'s env,
    the host and related options will now be derived from the routes'
    `default_url_options` and `ActionDispatch::Http::URL.secure_protocol`.

    This means that for an application with a configuration like:

      ```ruby
      Rails.application.default_url_options = { host: "rubyonrails.org" }
      Rails.application.config.force_ssl = true
      ```

    rendering a URL like:

      ```ruby
      ApplicationController.renderer.render inline: "<%= blog_url %>"
      ```

    will now return `"https://rubyonrails.org/blog"` instead of
    `"http://example.org/blog"`.

    *Jonathan Hefner*

*   Add details of cookie name and size to `CookieOverflow` exception.

    *Andy Waite*

*   Don't double log the `controller`, `action`, or `namespaced_controller` when using `ActiveRecord::QueryLog`

    Previously if you set `config.active_record.query_log_tags` to an array that included
    `:controller`, `:namespaced_controller`, or `:action`, that item would get logged twice.
    This bug has been fixed.

    *Alex Ghiculescu*

*   Add the following permissions policy directives: `hid`, `idle-detection`, `screen-wake-lock`,
    `serial`, `sync-xhr`, `web-share`.

    *Guillaume Cabanel*

*   The `speaker`, `vibrate`, and `vr` permissions policy directives are now
    deprecated.

    There is no browser support for these directives, and no plan for browser
    support in the future. You can just remove these directives from your
    application.

    *Jonathan Hefner*

*   Added the `:status` option to `assert_redirected_to` to specify the precise
    HTTP status of the redirect. Defaults to `:redirect` for backwards
    compatibility.

    *Jon Dufresne*

*   Rescue `JSON::ParserError` in Cookies JSON deserializer to discards marshal dumps:

    Without this change, if `action_dispatch.cookies_serializer` is set to `:json` and
    the app tries to read a `:marshal` serialized cookie, it would error out which wouldn't
    clear the cookie and force app users to manually clear it in their browser.

    (See #45127 for original bug discussion)

    *Nathan Bardoux*

*   Add `HTTP_REFERER` when following redirects on integration tests

    This makes `follow_redirect!` a closer simulation of what happens in a real browser

    *Felipe Sateler*

*   Added `exclude?` method to `ActionController::Parameters`.

    *Ian Neubert*

*   Rescue `EOFError` exception from `rack` on a multipart request.

    *Nikita Vasilevsky*

*   Log redirects from routes the same way as redirects from controllers.

    *Dennis Paagman*

*   Prevent `ActionDispatch::ServerTiming` from overwriting existing values in `Server-Timing`.
    Previously, if another middleware down the chain set `Server-Timing` header,
    it would overwritten by `ActionDispatch::ServerTiming`.

    *Jakub Malinowski*

*   Allow opting out of the `SameSite` cookie attribute when setting a cookie.

    You can opt out of `SameSite` by passing `same_site: nil`.

    `cookies[:foo] = { value: "bar", same_site: nil }`

    Previously, this incorrectly set the `SameSite` attribute to the value of the `cookies_same_site_protection` setting.

    *Alex Ghiculescu*

*   Allow using `helper_method`s in `content_security_policy` and `permissions_policy`

    Previously you could access basic helpers (defined in helper modules), but not
    helper methods defined using `helper_method`. Now you can use either.

    ```ruby
    content_security_policy do |p|
      p.default_src "https://example.com"
      p.script_src "https://example.com" if helpers.script_csp?
    end
    ```

    *Alex Ghiculescu*

*   Reimplement `ActionController::Parameters#has_value?` and `#value?` to avoid parameters and hashes comparison.

    Deprecated equality between parameters and hashes is going to be removed in Rails 7.2.
    The new implementation takes care of conversions.

    *Seva Stefkin*

*   Allow only String and Symbol keys in `ActionController::Parameters`.
    Raise `ActionController::InvalidParameterKey` when initializing Parameters
    with keys that aren't strings or symbols.

    *Seva Stefkin*

*   Add the ability to use custom logic for storing and retrieving CSRF tokens.

    By default, the token will be stored in the session.  Custom classes can be
    defined to specify arbitrary behavior, but the ability to store them in
    encrypted cookies is built in.

    *Andrew Kowpak*

*   Make ActionController::Parameters#values cast nested hashes into parameters.

    *Gannon McGibbon*

*   Introduce `html:` and `screenshot:` kwargs for system test screenshot helper

    Use these as an alternative to the already-available environment variables.

    For example, this will display a screenshot in iTerm, save the HTML, and output
    its path.

    ```ruby
    take_screenshot(html: true, screenshot: "inline")
    ```

    *Alex Ghiculescu*

*   Allow `ActionController::Parameters#to_h` to receive a block.

    *Bob Farrell*

*   Allow relative redirects when `raise_on_open_redirects` is enabled

    *Tom Hughes*

*   Allow Content Security Policy DSL to generate for API responses.

    *Tim Wade*

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

*   Make `redirect_to` return an empty response body.

    Application controllers that wish to add a response body after calling
    `redirect_to` can continue to do so.

    *Jon Dufresne*

*   Use non-capturing group for subdomain matching in `ActionDispatch::HostAuthorization`

    Since we do nothing with the captured subdomain group, we can use a non-capturing group instead.

    *Sam Bostock*

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

*   Make `Session#merge!` stringify keys.

    Previously `Session#update` would, but `merge!` wouldn't.

    *Drew Bragg*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/actionpack/CHANGELOG.md) for previous changes.
