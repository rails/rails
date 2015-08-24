## Rails 4.1.13 (August 24, 2015) ##

*   No changes.


## Rails 4.1.12 (June 25, 2015) ##

*   Add support for inline images in mailer previews by using an interceptor
    class to convert cid: urls in image src attributes to data urls. The
    interceptor is not enabled by default but can be done in an initializer:

        # config/initializer/preview_interceptors.rb
        ActionMailer::Base.register_preview_interceptor(ActionMailer::InlinePreviewInterceptor)

    *Andrew White*

*   Fix mailer previews with attachments by using the mail gem's own API to
    locate the first part of the correct mime type.

    Fixes #14435.

    *Andrew White*


## Rails 4.1.11 (June 16, 2015) ##

*   No changes.


## Rails 4.1.10 (March 19, 2015) ##

*   Add a new-line to the end of route method generated code.

    We need to add a `\n`, because we cannot have two routes
    in the same line.

    *arthurnn*

*   Force generated routes to be inserted into routes.rb

    *Andrew White*

*   Don't remove all line endings from routes.rb when revoking scaffold.

    Fixes #15913.

    *Andrew White*

*   Fix scaffold generator with `--helper=false` option.

    *Rafael Mendonça França*


## Rails 4.1.9 (January 6, 2015) ##

*   No changes.


## Rails 4.1.8 (November 16, 2014) ##

*   `secret_token` is now saved in `Rails.application.secrets.secret_token`
    and it falls back to the value of `config.secret_token` when it is not
    present in `config/secrets.yml`.

    *Benjamin Fleischer*

*   Specify dummy app's db migrate path in plugin's test_helper.rb.

    Fixes #16877.

    *Yukio Mizuta*

*   Change the path of dummy app location in plugin's test_helper.rb for cases
    you specify dummy_path option.

    *Yukio Mizuta*


## Rails 4.1.7.1 (November 19, 2014) ##

*   No changes.


## Rails 4.1.7 (October 29, 2014) ##

*   No changes.


## Rails 4.1.6 (September 11, 2014) ##

*   Scaffold generator `_form` partial adds `class="field"` for password
    confirmation fields.

    *noinkling*

*   Avoid namespacing routes inside engines.

    Mountable engines are namespaced by default so the generated routes
    were too while they should not.

    Fixes #14079.

    *Yves Senn*, *Carlos Antonio da Silva*, *Robin Dupret*


## Rails 4.1.5 (August 18, 2014) ##

*   Check attributes passed to `create_with` and `where`.

    Fixes CVE-2014-3514.

    *Rafael Mendonça França*


## Rails 4.1.4 (July 2, 2014) ##

*   No changes.


## Rails 4.1.3 (July 2, 2014) ##

*   No changes.


## Rails 4.1.2 (June 26, 2014) ##

*   Load database configuration from the first `database.yml` available in paths.

    *Pier-Olivier Thibault*

*   Fix `console` and `generators` blocks defined at different environments.

    Fixes #14748.

    *Rafael Mendonça França*

*   Move configuration of asset precompile list and version to an initializer.

    *Matthew Draper*


## Rails 4.1.1 (May 6, 2014) ##

*   No changes.


## Rails 4.1.0 (April 8, 2014) ##

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

*   Do not crash when `config/secrets.yml` is empty.

    *Yves Senn*

*   Set `dump_schema_after_migration` config values in production.

    Set `config.active_record.dump_schema_after_migration` as false
    in the generated `config/environments/production.rb` file.

    *Emil Soman*

*   Added Thor-action for creation of migrations.

    Fixes #13588, #12674.

    *Gert Goet*

*   Ensure that `bin/rails` is a file before trying to execute it.

    Fixes #13825.

    *bronzle*

*   Use single quotes in generated files.

    *Cristian Mircea Messel*, *Chulki Lee*

*   The `Gemfile` of new applications depends on SDoc ~> 0.4.0.

    *Xavier Noria*

*   `test_help.rb` now automatically checks/maintains your test database
    schema. (Use `config.active_record.maintain_test_schema = false` to
    disable.)

    *Jon Leighton*

*   Configure `secrets.yml` and `database.yml` to read configuration
    from the system environment by default for production.

    *José Valim*

*   `config.assets.raise_runtime_errors` is set to true by default

    This option has been introduced in
    [sprockets-rails#100][https://github.com/rails/sprockets-rails/pull/100]
    and defaults to true in new applications in development.

    *Richard Schneeman*

*   Generates `html` and `text` templates for mailers by default.

    *Kassio Borges*

*   Move `secret_key_base` from `config/initializers/secret_token.rb`
    to `config/secrets.yml`.

    `secret_key_base` is now saved in `Rails.application.secrets.secret_key_base`
    and it fallbacks to the value of `config.secret_key_base` when it is not
    present in `config/secrets.yml`.

    `config/initializers/secret_token.rb` is not generated by default
    in new applications.

    *Guillermo Iguaran*

*   Generate a new `secrets.yml` file in the `config` folder for new
    applications. By default, this file contains the application's `secret_key_base`,
    but it could also be used to store other secrets such as access keys for external
    APIs.

    The secrets added to this file will be accessible via `Rails.application.secrets`.
    For example, with the following `secrets.yml`:

        development:
          secret_key_base: 3b7cd727ee24e8444053437c36cc66c3
          some_api_key: SOMEKEY

    `Rails.application.secrets.some_api_key` will return `SOMEKEY` in the development
    environment.

    *Guillermo Iguaran*

*   Add `ENV['DATABASE_URL']` support in `rails dbconsole`. Fixes #13320.

    *Huiming Teo*

*   Add `Application#message_verifier` method to return a message verifier.

    This verifier can be used to generate and verify signed messages in the application.

        message = Rails.application.message_verifier(:sensitive_data).generate('my sensible data')
        Rails.application.message_verifier(:sensitive_data).verify(message)
        # => 'my sensible data'

    It is recommended not to use the same verifier for different things, so you can get different
    verifiers passing the name argument.

        message = Rails.application.message_verifier(:cookies).generate('my sensible cookie data')

    See the `ActiveSupport::MessageVerifier` documentation for more information.

    *Rafael Mendonça França*

*   The [Spring application
    preloader](https://github.com/rails/spring) is now installed
    by default for new applications. It uses the development group of
    the Gemfile, so will not be installed in production.

    *Jon Leighton*

*   Uses .railsrc while creating new plugin if it is available.

    Fixes #10700.

    *Prathamesh Sonpatki*

*   Remove turbolinks when generating a new application based on a template that skips it.

    Example:

        Skips turbolinks adding `add_gem_entry_filter { |gem| gem.name != "turbolinks" }`
        to the template.

    *Lauro Caetano*

*   Instrument an `load_config_initializer.railties` event on each load of configuration initializer
    from `config/initializers`. Subscribers should be attached before `load_config_initializers`
    initializer completed.

    Registering subscriber examples:

        # config/application.rb
        module RailsApp
          class Application < Rails::Application
            ActiveSupport::Notifications.subscribe('load_config_initializer.railties') do |*args|
              event = ActiveSupport::Notifications::Event.new(*args)
              puts "Loaded initializer #{event.payload[:initializer]} (#{event.duration}ms)"
            end
          end
        end

        # my_engine/lib/my_engine/engine.rb
        module MyEngine
          class Engine < ::Rails::Engine
            config.before_initialize do
              ActiveSupport::Notifications.subscribe('load_config_initializer.railties') do |*args|
                event = ActiveSupport::Notifications::Event.new(*args)
                puts "Loaded initializer #{event.payload[:initializer]} (#{event.duration}ms)"
              end
            end
          end
        end

    *Paul Nikitochkin*

*   Support for Pathnames in eager load paths.

    *Mike Pack*

*   Fixed missing line and shadow on service pages(404, 422, 500).

    *Dmitry Korotkov*

*   `BACKTRACE` environment variable to show unfiltered backtraces for
    test failures.

    Example:

        $ BACKTRACE=1 ruby -Itest ...
        # or with rake
        $ BACKTRACE=1 bin/rake

    *Yves Senn*

*   Removal of all javascript stuff (gems and files) when generating a new
    application using the `--skip-javascript` option.

    *Robin Dupret*

*   Make the application name snake cased when it contains spaces

    The application name is used to fill the `database.yml` and
    `session_store.rb` files ; previously, if the provided name
    contained whitespaces, it led to unexpected names in these files.

    *Robin Dupret*

*   Added `--model-name` option to `ScaffoldControllerGenerator`.

    *yalab*

*   Expose MiddlewareStack#unshift to environment configuration.

    *Ben Pickles*

*   `rails server` will only extend the logger to output to STDOUT
     in development environment.

    *Richard Schneeman*

*   Don't require passing path to app before options in `rails new`
    and `rails plugin new`

    *Piotr Sarnacki*

*   rake notes now searches *.less files

    *Josh Crowder*

*   Generate nested route for namespaced controller generated using
    `rails g controller`.
    Fixes #11532.

    Example:

        rails g controller admin/dashboard index

        # Before:
        get "dashboard/index"

        # After:
        namespace :admin do
          get "dashboard/index"
        end

    *Prathamesh Sonpatki*

*   Fix the event name of action_dispatch requests.

    *Rafael Mendonça França*

*   Make `config.log_level` work with custom loggers.

    *Max Shytikov*

*   Changed stylesheet load order in the stylesheet manifest generator.
    Fixes #11639.

    *Pawel Janiak*

*   Added generated unit test for generator generator using new
    `test:generators` rake task.

    *Josef Šimánek*

*   Removed `update:application_controller` rake task.

    *Josef Šimánek*

*   Fix `rake environment` to do not eager load modules

    *Paul Nikitochkin*

*   Fix `rake notes` to look into `*.sass` files

    *Yuri Artemev*

*   Removed deprecated `Rails.application.railties.engines`.

    *Arun Agrawal*

*   Removed deprecated threadsafe! from Rails Config.

    *Paul Nikitochkin*

*   Remove deprecated `ActiveRecord::Generators::ActiveModel#update_attributes` in
    favor of `ActiveRecord::Generators::ActiveModel#update`.

    *Vipul A M*

*   Remove deprecated `config.whiny_nils` option.

    *Vipul A M*

*   Rename `commands/plugin_new.rb` to `commands/plugin.rb` and fix references

    *Richard Schneeman*

*   Fix `rails plugin --help` command.

    *Richard Schneeman*

*   Omit turbolinks configuration completely on skip_javascript generator option.

    *Nikita Fedyashev*

*   Removed deprecated rake tasks for running tests: `rake test:uncommitted` and
    `rake test:recent`.

    *John Wang*

*   Clearing autoloaded constants triggers routes reloading.
    Fixes #10685.

    *Xavier Noria*

*   Fixes bug with scaffold generator with `--assets=false --resource-route=false`.
    Fixes #9525.

    *Arun Agrawal*

*   Rails::Railtie no longer forces the Rails::Configurable module on everything
    that subclasses it. Instead, the methods from Rails::Configurable have been
    moved to class methods in Railtie and the Railtie has been made abstract.

    *John Wang*

*   Changes repetitive th tags to use colspan attribute in `index.html.erb` template.

    *Sıtkı Bağdat*

Please check [4-0-stable](https://github.com/rails/rails/blob/4-0-stable/railties/CHANGELOG.md) for previous changes.
