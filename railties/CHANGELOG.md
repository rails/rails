*   Deprecate `config.serve_static_assets` in favor of `config.serve_static_files`
    to clarify that the option is unrelated to the asset pipeline.

    *Godfrey Chan*

*   `config.serve_static_files` can now be set from an environment variable in
    production mode. The feature remains off by default, but can be enabled by
    setting `RAILS_SERVE_STATIC_FILES` to a non-empty string at boot time.

    *Richard Schneeman*, *Godfrey Chan*

*   Generated migrations add the appropriate foreign key constraints to
    references.

    *Derek Prior*

*   Deprecate different default for `log_level` in production.

    *Godfrey Chan*, *Matthew Draper*

*   Generated `.gitignore` excludes the whole `log/` directory, not only
    `*.log` files.

    *ShunsukeAida*

*   `Rails::Paths::Path.unshift` now has the same interface as `Array.unshift`.

    *Igor Kapkov*

*   Make `rake test` run all tests in test folder.

    Deprecate `rake test:all` and replace `rake test:all:db` with `rake test:db`

    *David Geukers*

*   `secret_token` is now saved in `Rails.application.secrets.secret_token`
    and it falls back to the value of `config.secret_token` when it is not
    present in `config/secrets.yml`.

    *Benjamin Fleischer*

*   Remove `--skip-action-view` option from `Rails::Generators::AppBase`.

    Fixes #17023.

    *Dan Olson*

*   Specify dummy app's db migrate path in plugin's test_helper.rb.

    Fixes #16877.

    *Yukio Mizuta*

*   Inject `Rack::Lock` if `config.eager_load` is false.

    Fixes #15089.

    *Xavier Noria*

*   Change the path of dummy app location in plugin's test_helper.rb for cases
    you specify dummy_path option.

    *Yukio Mizuta*

*   Fix a bug in the `gem` method for Rails templates when non-String options
    are used.

    Fixes #16709.

    *Yves Senn*

*   The [web-console](https://github.com/rails/web-console) gem is now
    installed by default for new applications. It can help you debug
    development exceptions by spawning an interactive console in its cause
    binding.

    *Ryan Dao*, *Genadi Samokovarov*, *Guillermo Iguaran*

*   Add a `required` option to the model generator for associations

    *Sean Griffin*

*   Add `after_bundle` callbacks in Rails templates. Useful for allowing the
    generated binstubs to be added to version control.

    Fixes #16292.

    *Stefan Kanev*

*   Pull in the custom configuration concept from dhh/custom_configuration, which allows you to
    configure your own code through the Rails configuration object with custom configuration:

        # config/environments/production.rb
        config.x.payment_processing.schedule = :daily
        config.x.payment_processing.retries  = 3
        config.x.super_debugger              = true

    These configuration points are then available through the configuration object:

        Rails.configuration.x.payment_processing.schedule # => :daily
        Rails.configuration.x.payment_processing.retries  # => 3
        Rails.configuration.x.super_debugger              # => true

    *DHH*

*   Scaffold generator `_form` partial adds `class="field"` for password
    confirmation fields.

    *noinkling*

*   Add `Rails::Application.config_for` to load a configuration for the current
    environment.

        # config/exception_notification.yml:
        production:
          url: http://127.0.0.1:8080
          namespace: my_app_production
        development:
          url: http://localhost:3001
          namespace: my_app_development

        # config/production.rb
        Rails.application.configure do
          config.middleware.use ExceptionNotifier, config_for(:exception_notification)
        end

    *Rafael Mendonça França*, *DHH*

*   Deprecate `Rails::Rack::LogTailer` without replacement.

    *Rafael Mendonça França*

*   Add `--skip-turbolinks` option to the app generator.

    *Rafael Mendonça França*

*   Invalid `bin/rails generate` commands will now show spelling suggestions.

    *Richard Schneeman*

*   Add `bin/setup` script to bootstrap an application.

    *Yves Senn*

*   Replace double quotes with single quotes while adding an entry into Gemfile.

    *Alexander Belaev*

*   Default `config.assets.digest` to `true` in development.

    *Dan Kang*

*   Load database configuration from the first `database.yml` available in paths.

    *Pier-Olivier Thibault*

*   Reading name and email from git for plugin gemspec.

    Fixes #9589.

    *Arun Agrawal*, *Abd ar-Rahman Hamidi*, *Roman Shmatov*

*   Fix `console` and `generators` blocks defined at different environments.

    Fixes #14748.

    *Rafael Mendonça França*

*   Move configuration of asset precompile list and version to an initializer.

    *Matthew Draper*

*   Remove sqlite3 lines from `.gitignore` if the application is not using sqlite3.

    *Dmitrii Golub*

*   Add public API to register new extensions for `rake notes`.

    Example:

        config.annotations.register_extensions("scss", "sass") { |tag| /\/\/\s*(#{tag}):?\s*(.*)$/ }

    *Roberto Miranda*

*   Removed unnecessary `rails application` command.

    *Arun Agrawal*

*   Make the `rails:template` rake task load the application's initializers.

    Fixes #12133.

    *Robin Dupret*

*   Introduce `Rails.gem_version` as a convenience method to return
    `Gem::Version.new(Rails.version)`, suggesting a more reliable way to perform
    version comparison.

    Example:

        Rails.version #=> "4.1.2"
        Rails.gem_version #=> #<Gem::Version "4.1.2">

        Rails.version > "4.1.10" #=> false
        Rails.gem_version > Gem::Version.new("4.1.10") #=> true
        Gem::Requirement.new("~> 4.1.2") =~ Rails.gem_version #=> true

    *Prem Sichanugrist*

*   Avoid namespacing routes inside engines.

    Mountable engines are namespaced by default so the generated routes
    were too while they should not.

    Fixes #14079.

    *Yves Senn*, *Carlos Antonio da Silva*, *Robin Dupret*

Please check [4-1-stable](https://github.com/rails/rails/blob/4-1-stable/railties/CHANGELOG.md) for previous changes.
