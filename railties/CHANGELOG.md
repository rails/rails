*   The scaffold generator now generates valid html when the model has_many_attached.

    *Patricio Mac Adden*

*   Add `application-name` metadata to application layout

    The following metatag will be added to `app/views/layouts/application.html.erb`

    ```html
    <meta name="application-name" content="Name of Rails Application">
    ```

    *Steve Polito*

*   Use `secret_key_base` from ENV or credentials when present locally.

    When ENV["SECRET_KEY_BASE"] or
    `Rails.application.credentials.secret_key_base` is set for test or
    development, it is used for the `Rails.config.secret_key_base`,
    instead of generating a `tmp/local_secret.txt` file.

    *Petrik de Heus*

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
