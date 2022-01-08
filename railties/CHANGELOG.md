*   Remove `Rack::Sendfile` from the default middleware stack and deprecate
    referencing it in middleware operations.

    Removed configuration option for specifying the header used for sending files:

    ```
    config.action_dispatch.x_sendfile_header = 'X-Sendfile'
    ```

    `Rack::Sendfile` instead can be explicitly added if needed:

    ```
    use Rack::SendFile, 'X-Sendfile'
    ```

    *Stanislav Valkanov*

*   No longer add autoloaded paths to `$LOAD_PATH`.

    This means it won't be possible to load them with a manual `require` call, the class or module can be referenced instead.

    Reducing the size of `$LOAD_PATH` speed-up `require` calls for apps not using `bootsnap`, and reduce the
    size of the `bootsnap` cache for the others.

    *Jean Boussier*

*   Remove default `X-Download-Options` header

    This header is currently only used by Internet Explorer which
    will be discontinued in 2022 and since Rails 7 does not fully
    support Internet Explorer this header should not be a default one.

    *Harun Sabljaković*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/railties/CHANGELOG.md) for previous changes.
