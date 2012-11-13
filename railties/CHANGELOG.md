## Rails 4.0.0 (unreleased) ##

*   Add dummy app Rake tasks when --skip-test-unit and --dummy-path is passed to the plugin generator.
    Fix #8121

    *Yves Senn*

*   Ensure that RAILS_ENV is set when accessing Rails.env *Steve Klabnik*

*   Don't eager-load app/assets and app/views *Elia Schito*

*   Add `.rake` to list of file extensions included by `rake notes` and `rake notes:custom`. *Brent J. Nordquist*

*   New test locations `test/models`, `test/helpers`, `test/controllers`, and
    `test/mailers`. Corresponding rake tasks added as well. *Mike Moore*

*   Set a different cache per environment for assets pipeline
    through `config.assets.cache`.

    *Guillermo Iguaran*

*   `Rails.public_path` now returns a Pathname object. *Prem Sichanugrist*

*   Remove highly uncommon `config.assets.manifest` option for moving the manifest path.
    This option is now unsupported in sprockets-rails.

    *Guillermo Iguaran & Dmitry Vorotilin*

*   Add `config.action_controller.permit_all_parameters` to disable
    StrongParameters protection, it's false by default.

    *Guillermo Iguaran*

*   Remove `config.active_record.whitelist_attributes` and
    `config.active_record.mass_assignment_sanitizer` from new applications since
    MassAssignmentSecurity has been extracted from Rails.

    *Guillermo Iguaran*

*   Change `rails new` and `rails plugin new` generators to name the `.gitkeep` files
    as `.keep` in a more SCM-agnostic way.

    Change `--skip-git` option to only skip the `.gitignore` file and still generate
    the `.keep` files.

    Add `--skip-keeps` option to skip the `.keep` files.

    *Derek Prior & Francesco Rodriguez*

*   Fixed support for DATABASE_URL environment variable for rake db tasks. *Grace Liu*

*   rails dbconsole now can use SSL for MySQL. The database.yml options sslca, sslcert, sslcapath, sslcipher,
    and sslkey now affect rails dbconsole. *Jim Kingdon and Lars Petrus*

*   Correctly handle SCRIPT_NAME when generating routes to engine in application
    that's mounted at a sub-uri. With this behavior, you *should not* use
    default_url_options[:script_name] to set proper application's mount point by
    yourself. *Piotr Sarnacki*

*   `config.threadsafe!` is deprecated in favor of `config.eager_load` which provides a more fine grained control on what is eager loaded *José Valim*

*   The migration generator will now produce AddXXXToYYY/RemoveXXXFromYYY migrations with references statements, for instance

        rails g migration AddReferencesToProducts user:references supplier:references{polymorphic}

    will generate the migration with:

        add_reference :products, :user, index: true
        add_reference :products, :supplier, polymorphic: true, index: true

    *Aleksey Magusev*

*   Allow scaffold/model/migration generators to accept a `polymorphic` modifier
    for `references`/`belongs_to`, for instance

        rails g model Product supplier:references{polymorphic}

    will generate the model with `belongs_to :supplier, polymorphic: true`
    association and appropriate migration.

    *Aleksey Magusev*

*   Set `config.active_record.migration_error` to `:page_load` for development *Richard Schneeman*

*   Add runner to Rails::Railtie as a hook called just after runner starts. *José Valim & kennyj*

*   Add `/rails/info/routes` path, displays same information as `rake routes` *Richard Schneeman & Andrew White*

*   Improved `rake routes` output for redirects *Łukasz Strzałkowski & Andrew White*

*   Load all environments available in `config.paths["config/environments"]`. *Piotr Sarnacki*

*   Add `config.queue_consumer` to change the job queue consumer from the default `ActiveSupport::ThreadedQueueConsumer`. *Carlos Antonio da Silva*

*   Add `Rails.queue` for processing jobs in the background. *Yehuda Katz*

*   Remove Rack::SSL in favour of ActionDispatch::SSL. *Rafael Mendonça França*

*   Remove Active Resource from Rails framework. *Prem Sichangrist*

*   Allow to set class that will be used to run as a console, other than IRB, with `Rails.application.config.console=`. It's best to add it to `console` block. *Piotr Sarnacki*

    Example:

        # it can be added to config/application.rb
        console do
          # this block is called only when running console,
          # so we can safely require pry here
          require "pry"
          config.console = Pry
        end

*   Add convenience `hide!` method to Rails generators to hide current generator
    namespace from showing when running `rails generate`. *Carlos Antonio da Silva*

*   Scaffold now uses `content_tag_for` in index.html.erb *José Valim*

*   Rails::Plugin has gone. Instead of adding plugins to vendor/plugins use gems or bundler with path or git dependencies. *Santiago Pastorino*

*   Set config.action_mailer.async = true to turn on asynchronous
    message delivery *Brian Cardarella*

Please check [3-2-stable](https://github.com/rails/rails/blob/3-2-stable/railties/CHANGELOG.md) for previous changes.
