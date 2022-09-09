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
*   Add `HTTP_REFERER` when following redirects on integration tests

    This makes `follow_redirect!` a closer simulation of what happens in a real browser

    *Felipe Sateler*


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
