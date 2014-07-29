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
        MyApp::Application.configure do
          config.middleware.use ExceptionNotifier, config_for(:exception_notification)
        end

    *Rafael Mendonça França*, *DHH*

*   Deprecate `Rails::Rack::LogTailer` without replacement.

    *Rafael Mendonça França*

*   Add a generic --skip-gems options to generator

    This option is useful if users want to remove some gems like jbuilder,
    turbolinks, coffee-rails, etc that don't have specific options on the
    generator.

        rails new my_app --skip-gems turbolinks coffee-rails

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
