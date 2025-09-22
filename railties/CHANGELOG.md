## Rails 8.0.3 (September 22, 2025) ##

*   Fix `polymorphic_url` and `polymorphic_path` not working when routes are not loaded.

    *Édouard Chin*

*   Fix Rails console to not override user defined IRB_NAME.

    Only change the prompt name if it hasn't been customized in `.irbrc`.

    *Jarrett Lusso*


## Rails 8.0.2.1 (August 13, 2025) ##

*   No changes.


## Rails 8.0.2 (March 12, 2025) ##

*   Fix Rails console to load routes.

    Otherwise `*_path` and `*url` methods are missing on the `app` object.

    *Édouard Chin*

*   Update `rails new --minimal` option

    Extend the `--minimal` flag to exclude recently added features:
    `skip_brakeman`, `skip_ci`, `skip_docker`, `skip_kamal`, `skip_rubocop`, `skip_solid` and `skip_thruster`.

    *eelcoj*

*   Use `secret_key_base` from ENV or credentials when present locally.

    When ENV["SECRET_KEY_BASE"] or
    `Rails.application.credentials.secret_key_base` is set for test or
    development, it is used for the `Rails.config.secret_key_base`,
    instead of generating a `tmp/local_secret.txt` file.

    *Petrik de Heus*


## Rails 8.0.1 (December 13, 2024) ##

*   Skip generation system tests related code for CI when `--skip-system-test` is given.

    *fatkodima*

*   Don't add bin/thrust if thruster is not in Gemfile.

    *Étienne Barrié*

*   Don't install a package for system test when applications don't use it.

    *y-yagi*


## Rails 8.0.0.1 (December 10, 2024) ##

*   No changes.


## Rails 8.0.0 (November 07, 2024) ##

*   No changes.


## Rails 8.0.0.rc2 (October 30, 2024) ##

*   Fix incorrect database.yml with `skip_solid`.

    *Joé Dupuis*

*   Set `Regexp.timeout` to `1`s by default to improve security over Regexp Denial-of-Service attacks.

    *Rafael Mendonça França*


## Rails 8.0.0.rc1 (October 19, 2024) ##

*   Remove deprecated support to extend Rails console through `Rails::ConsoleMethods`.

    *Rafael Mendonça França*

*   Remove deprecated file `rails/console/helpers`.

    *Rafael Mendonça França*

*   Remove deprecated file `rails/console/app`.

    *Rafael Mendonça França*

*   Remove deprecated `config.read_encrypted_secrets`.

    *Rafael Mendonça França*

*   Add Kamal support for devcontainers

    Previously generated devcontainer could not use docker and therefore Kamal.

    *Joé Dupuis*


## Rails 8.0.0.beta1 (September 26, 2024) ##

*   Exit `rails g` with code 1 if generator could not be found.

    Previously `rails g` returned 0, which would make it harder to catch typos in scripts calling `rails g`.

    *Christopher Özbek*

*   Remove `require_*` statements from application.css to align with the transition from Sprockets to Propshaft.

    With Propshaft as the default asset pipeline in Rails 8, the require_tree and require_self clauses in application.css are no longer necessary, as they were specific to Sprockets. Additionally, the comment has been updated to clarify that CSS precedence now follows standard cascading order without automatic prioritization by the asset pipeline.

    *Eduardo Alencar*

*   Do not include redis by default in generated Dev Containers.

    Now that applications use the Solid Queue and Solid Cache gems by default, we do not need to include redis
    in the Dev Container. We will only include redis if `--skip-solid` is used when generating an app that uses
    Active Job or Action Cable.

    When generating a Dev Container for an existing app, we will not include redis if either of the solid gems
    are in use.

    *Andrew Novoselac*

*   Use [Solid Cable](https://github.com/rails/solid_cable) as the default Action Cable adapter in production, configured as a separate queue database in config/database.yml. It keeps messages in a table and continuously polls for updates. This makes it possible to drop the common dependency on Redis, if it isn't needed for any other purpose. Despite polling, the performance of Solid Cable is comparable to Redis in most situations. And in all circumstances, it makes it easier to deploy Rails when Redis is no longer a required dependency for Action Cable functionality.

    *DHH*

*   Use [Solid Queue](https://github.com/rails/solid_queue) as the default Active Job backend in production, configured as a separate queue database in config/database.yml. In a single-server deployment, it'll run as a Puma plugin. This is configured in `config/deploy.yml` and can easily be changed to use a dedicated jobs machine.

    *DHH*

*   Use [Solid Cache](https://github.com/rails/solid_cache) as the default Rails.cache backend in production, configured as a separate cache database in config/database.yml.

    *DHH*

*   Add Rails::Rack::SilenceRequest middleware and use it via `config.silence_healthcheck_path = path`
    to silence requests to "/up". This prevents the Kamal-required health checks from clogging up
    the production logs.

    *DHH*

*   Introduce `mariadb-mysql` and `mariadb-trilogy` database options for `rails new`

    When used with the `--devcontainer` flag, these options will use `mariadb` as the database for the
    Dev Container. The original `mysql` and `trilogy` options will use `mysql`. Users who are not
    generating a Dev Container do not need to use the new options.

    *Andrew Novoselac*

*   Deprecate `::STATS_DIRECTORIES`.

    The global constant `STATS_DIRECTORIES` has been deprecated in favor of
    `Rails::CodeStatistics.register_directory`.

    Add extra directories with `Rails::CodeStatistics.register_directory(label, path)`:

    ```ruby
    require "rails/code_statistics"
    Rails::CodeStatistics.register_directory('My Directory', 'path/to/dir')
    ```

    *Petrik de Heus*

*   Enable query log tags by default on development env

    This can be used to trace troublesome SQL statements back to the application
    code that generated these statements. It is also useful when using multiple
    databases because the query logs can identify which database is being used.

    *Matheus Richard*

*   Defer route drawing to the first request, or when url_helpers are called

    Executes the first routes reload in middleware, or when a route set's
    url_helpers receives a route call / asked if it responds to a route.
    Previously, this was executed unconditionally on boot, which can
    slow down boot time unnecessarily for larger apps with lots of routes.

    Environments like production that have `config.eager_load = true` will
    continue to eagerly load routes on boot.

    *Gannon McGibbon*

*   Generate form helpers to use `textarea*` methods instead of `text_area*` methods

    *Sean Doyle*

*   Add authentication generator to give a basic start to an authentication system using database-tracked sessions and password reset.

    Generate with...

    ```
    bin/rails generate authentication
    ```

    Generated files:

    ```
    app/models/current.rb
    app/models/user.rb
    app/models/session.rb
    app/controllers/sessions_controller.rb
    app/controllers/passwords_controller.rb
    app/mailers/passwords_mailer.rb
    app/views/sessions/new.html.erb
    app/views/passwords/new.html.erb
    app/views/passwords/edit.html.erb
    app/views/passwords_mailer/reset.html.erb
    app/views/passwords_mailer/reset.text.erb
    db/migrate/xxxxxxx_create_users.rb
    db/migrate/xxxxxxx_create_sessions.rb
    test/mailers/previews/passwords_mailer_preview.rb
    ```

    *DHH*


*   Add not-null type modifier to migration attributes.

    Generating with...

    ```
    bin/rails generate migration CreateUsers email_address:string!:uniq password_digest:string!
    ```

    Produces:

    ```ruby
    class CreateUsers < ActiveRecord::Migration[8.0]
      def change
        create_table :users do |t|
          t.string :email_address, null: false
          t.string :password_digest, null: false

          t.timestamps
        end
        add_index :users, :email_address, unique: true
      end
    end
    ```

    *DHH*

*   Add a `script` folder to applications, and a scripts generator.

    The new `script` folder is meant to hold one-off or general purpose scripts,
    such as data migration scripts, cleanup scripts, etc.

    A new script generator allows you to create such scripts:

    ```
    bin/rails generate script my_script
    bin/rails generate script data/backfill
    ```

    You can run the generated script using:

    ```
    bundle exec ruby script/my_script.rb
    bundle exec ruby script/data/backfill.rb
    ```

    *Jerome Dalbert*, *Haroon Ahmed*

*   Deprecate `bin/rake stats` in favor of `bin/rails stats`.

    *Juan Vásquez*

*   Add internal page `/rails/info/notes`, that displays the same information as `bin/rails notes`.

    *Deepak Mahakale*

*   Add Rubocop and GitHub Actions to plugin generator.
    This can be skipped using --skip-rubocop and --skip-ci.

    *Chris Oliver*

*   Use Kamal for deployment by default, which includes generating a Rails-specific config/deploy.yml.
    This can be skipped using --skip-kamal. See more: https://kamal-deploy.org/

    *DHH*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/railties/CHANGELOG.md) for previous changes.
