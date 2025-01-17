*   Add `current_user` helper to authentication concern

    *Chris Kottom*

*   The authentication generator's `SessionsController` sets the `Clear-Site-Data` header on logout.

    By default the header will be set to `"cache","storage"` to help prevent data leakage after
    logout via the browser's "back/forward cache".

    *Mike Dalessio*

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
