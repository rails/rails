*   Remove `Rack::Sendfile` from the default middleware stack and deprecate
    referencing it in middleware operations.

    Deprecate configuration option for specifying the header used for sending files:

    ```
    config.action_dispatch.x_sendfile_header = 'X-Sendfile'
    ```

    `Rack::Sendfile` instead can be explicitly added if needed:

    ```
    use Rack::SendFile, 'X-Sendfile'
    ```

    *Stanislav Valkanov*

*   Introduce `RAILS_MASTER_KEY` placeholder in generated ci.yml files

    *Steve Polito*

*   Colorize the Rails console prompt even on non standard environments.

    *Lorenzo Zabot*

*   Don't enable YJIT in development and test environments

    Development and test environments tend to reload code and redefine methods (e.g. mocking),
    hence YJIT isn't generally faster in these environments.

    *Ali Ismayilov*, *Jean Boussier*

*   Only include PermissionsPolicy::Middleware if policy is configured.

    *Petrik de Heus*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/railties/CHANGELOG.md) for previous changes.
