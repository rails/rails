*   Fix `ActionContoller::Live` to copy the IsolatedExecutionState in the ephemeral thread.

    Since it's inception `ActionContoller::Live` has been copying thread local variables
    to keep things such as `CurrentAttributes` set from middlewares working in the controller action.

    With the introduction of `IsolatedExecutionState` in 7.0, some of that global state was lost in
    `ActionContoller::Live` controllers.

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
