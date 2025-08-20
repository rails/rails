*   Add command `rails credentials:fetch PATH` to get the value of a credential from the credentials file.

    ```bash
    $ bin/rails credentials:fetch kamal_registry.password
    ```

    *Matthew Nguyen*, *Jean Boussier*

*   Generate static BCrypt password digests in fixtures instead of dynamic ERB expressions.

    Previously, fixtures with password digest attributes used `<%= BCrypt::Password.create("secret") %>`,
    which regenerated the hash on each test run. Now generates a static hash with a comment
    showing how to recreate it.

    *Nate Smith*, *Cassia Scheffer*

*   Broaden the `.gitignore` entry when adding a credentials key to ignore all key files.

    *Greg Molnar*

*   Remove unnecessary `ruby-version` input from `ruby/setup-ruby`

    *TangRufus*

*   Add --reset option to bin/setup which will call db:reset as part of the setup.

    *DHH*

*   Add RuboCop cache restoration to RuboCop job in GitHub Actions workflow templates.

    *Lovro Bikić*

*   Skip generating mailer-related files in authentication generator if the application does
    not use ActionMailer

    *Rami Massoud*

*   Introduce `bin/ci` for running your tests, style checks, and security audits locally or in the cloud.

    The specific steps are defined by a new DSL in `config/ci.rb`.

    ```ruby
    ActiveSupport::ContinuousIntegration.run do
      step "Setup", "bin/setup --skip-server"
      step "Style: Ruby", "bin/rubocop"
      step "Security: Gem audit", "bin/bundler-audit"
      step "Tests: Rails", "bin/rails test test:system"
    end
    ```

    Optionally use [gh-signoff](https://github.com/basecamp/gh-signoff) to
    set a green PR status - ready for merge.

    *Jeremy Daer*, *DHH*

*   Generate session controller tests when running the authentication generator.

    *Jerome Dalbert*

*   Add bin/bundler-audit and config/bundler-audit.yml for discovering and managing known security problems with app gems.

    *DHH*

*   Rails no longer generates a `bin/bundle` binstub when creating new applications.

    The `bin/bundle` binstub used to help activate the right version of bundler.
    This is no longer necessary as this mechanism is now part of Rubygem itself.

    *Edouard Chin*

*   Add a `SessionTestHelper` module with `sign_in_as(user)` and `sign_out` test helpers when
    running `rails g authentication`. Simplifies authentication in integration tests.

    *Bijan Rahnema*

*   Rate limit password resets in authentication generator

    This helps mitigate abuse from attackers spamming the password reset form.

    *Chris Oliver*

*   Update `rails new --minimal` option

    Extend the `--minimal` flag to exclude recently added features:
    `skip_brakeman`, `skip_ci`, `skip_docker`, `skip_kamal`, `skip_rubocop`, `skip_solid` and `skip_thruster`.

    *eelcoj*

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

*   Only add browser restrictions for a new Rails app when using importmap.

    *Lucas Dohmen*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/railties/CHANGELOG.md) for previous changes.
