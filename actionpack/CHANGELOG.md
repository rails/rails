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
