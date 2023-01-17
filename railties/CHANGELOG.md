## Rails 6.0.6.1 (January 17, 2023) ##

*   No changes.


## Rails 6.0.6 (September 09, 2022) ##

*   No changes.


## Rails 6.0.5.1 (July 12, 2022) ##

*   No changes.


## Rails 6.0.5 (May 09, 2022) ##

*   No changes.


## Rails 6.0.4.8 (April 26, 2022) ##

*   No changes.


## Rails 6.0.4.7 (March 08, 2022) ##

*   No changes.


## Rails 6.0.4.6 (February 11, 2022) ##

*   No changes.


## Rails 6.0.4.5 (February 11, 2022) ##

*   No changes.


## Rails 6.0.4.4 (December 15, 2021) ##

*   No changes.


## Rails 6.0.4.3 (December 14, 2021) ##

*   Allow localhost with a port by default in development

    [Fixes: #43864]

## Rails 6.0.4.2 (December 14, 2021) ##

*   No changes.


## Rails 6.0.4.1 (August 19, 2021) ##

*   No changes.


## Rails 6.0.4 (June 15, 2021) ##

*   Allow relative paths with trailing slashes to be passed to `rails test`.

    *Eugene Kenny*

*   Return a 405 Method Not Allowed response when a request uses an unknown HTTP method.

    Fixes #38998.

    *Loren Norman*


## Rails 6.0.3.7 (May 05, 2021) ##

*   No changes.


## Rails 6.0.3.6 (March 26, 2021) ##

*   No changes.


## Rails 6.0.3.5 (February 10, 2021) ##

*   No changes.



## Rails 6.0.3.4 (October 07, 2020) ##

*   No changes.


## Rails 6.0.3.3 (September 09, 2020) ##

*   No changes.


## Rails 6.0.3.2 (June 17, 2020) ##

*   No changes.


## Rails 6.0.3.1 (May 18, 2020) ##

*   No changes.


## Rails 6.0.3 (May 06, 2020) ##

*   Cache compiled view templates when running tests by default

    When generating a new app without `--skip-spring`, caching classes is
    disabled in `environments/test.rb`. This implicitly disables caching
    view templates too. This change will enable view template caching by
    adding this to the generated `environments/test.rb`:

    ````ruby
    config.action_view.cache_template_loading = true
    ````

    *Jorge Manrubia*

*   `Rails::Application#eager_load!` is available again to load application code
    manually as it was possible in previous versions.

    Please, note this is not integrated with the whole eager loading logic that
    runs when Rails boots with eager loading enabled, you can think of this
    method as a vanilla recursive code loader.

    This ability has been restored because there are some use cases for it, such
    as indexers that need to have all application classes and modules in memory.

    *Xavier Noria*

*   Generators that inherit from NamedBase respect `--force` option

    *Josh Brody*

*   Regression fix: The Rake task `zeitwerk:check` supports eager loaded
    namespaces which do not have eager load paths, like the recently added
    `i18n`. These namespaces are only required to respond to `eager_load!`.

    *Xavier Noria*


## Rails 6.0.2.2 (March 19, 2020) ##

*   No changes.


## Rails 6.0.2.1 (December 18, 2019) ##

*   No changes.


## Rails 6.0.2 (December 13, 2019) ##

*   Fix the collision check for the scaffold generator.

    *Ryan Robeson*

## Rails 6.0.1 (November 5, 2019) ##

*   The `zeitwerk:check` Rake task reports files outside the app's root
    directory, as in engines loaded from gems.

    *Xavier Noria*

*   Fixed a possible error when using the evented file update checker.

    *Yuji Yaginuma*

*   The sqlite3 database files created by the parallel testing feature are
    included in the default `.gitignore` file for newly-generated apps.

    *Yasuo Honda*

*   `rails new` generates a `.keep` file in `tmp/pids`. This fixes starting
    a server via `rackup` instead of `rails server`.

    *Rafael Mendonça França*


## Rails 6.0.0 (August 16, 2019) ##

*   `Rails.autoloaders.log!` is a logging shortcut to get the activity of the
    loaders printed to standard output. May be handy for troubleshooting.

    *Xavier Noria*


## Rails 6.0.0.rc2 (July 22, 2019) ##

*   The new configuration point `config.add_autoload_paths_to_load_path` allows
    users to opt-out from adding autoload paths to `$LOAD_PATH`. This flag is
    `true` by default, but it is recommended to be set to `false` in `:zeitwerk`
    mode early, in `config/application.rb`.

    Zeitwerk uses only absolute paths internally, and applications running in
    `:zeitwerk` mode do not need `require_dependency`, so models, controllers,
    jobs, etc. do not need to be in `$LOAD_PATH`. Setting this to `false` saves
    Ruby from checking these directories when resolving `require` calls with
    relative paths, and saves Bootsnap work and RAM, since it does not need to
    build an index for them.

    *Xavier Noria*

## Rails 6.0.0.rc1 (April 24, 2019) ##

*   Applications upgrading to Rails 6 can run the command

    ```
    bin/rails zeitwerk:check
    ```

    to check if the project structure they were using with the classic
    autoloader is compatible with `:zeitwerk` mode.

    *Matilda Smeds* & *Xavier Noria*

*   Allow loading seeds without ActiveJob.

    Fixes #35782

    *Jeremy Weathers*

*   `null: false` is set in the migrations by default for column pointed by
    `belongs_to` / `references` association generated by model generator.

    Also deprecate passing {required} to the model generator.

    *Prathamesh Sonpatki*

*   New applications get `config.cache_classes = false` in `config/environments/test.rb`
    unless `--skip-spring`.

    *Xavier Noria*

*   Autoloading during initialization is deprecated.

    *Xavier Noria*

*   Only force `:async` ActiveJob adapter to `:inline` during seeding.

    *BatedUrGonnaDie*

*   The `connection` option of `rails dbconsole` command is deprecated in
    favor of `database` option.

    *Yuji Yaginuma*

*   Replace `chromedriver-helper` gem with `webdrivers` in default Gemfile.
    `chromedriver-helper` is deprecated as of March 31, 2019 and won't
    receive any further updates.

    *Guillermo Iguaran‮*

*   Applications running in `:zeitwerk` mode that use `bootsnap` need
    to upgrade `bootsnap` to at least 1.4.2.

    *Xavier Noria*

*   Add `config.disable_sandbox` option to Rails console.

    This setting will disable `rails console --sandbox` mode, preventing
    developer from accidentally starting a sandbox console,
    which when left inactive, can cause the database server to run out of memory.

    *Prem Sichanugrist*

*   Add `-e/--environment` option to `rails initializers`.

    *Yuji Yaginuma*


## Rails 6.0.0.beta3 (March 11, 2019) ##

*   Generate random development secrets

    A random development secret is now generated to tmp/development_secret.txt

    This avoids an issue where development mode servers were vulnerable to
    remote code execution.

    Fixes CVE-2019-5420

    *Eileen M. Uchitelle*, *Aaron Patterson*, *John Hawthorn*


## Rails 6.0.0.beta2 (February 25, 2019) ##

*   Fix non-symbol access to nested hashes returned from `Rails::Application.config_for`
    being broken by allowing non-symbol access with a deprecation notice.

    *Ufuk Kayserilioglu*

*   Fix deeply nested namespace command printing.

    *Gannon McGibbon*


## Rails 6.0.0.beta1 (January 18, 2019) ##

*   Remove deprecated `after_bundle` helper inside plugins templates.

    *Rafael Mendonça França*

*   Remove deprecated support to old `config.ru` that use the application class as argument of `run`.

    *Rafael Mendonça França*

*   Remove deprecated `environment` argument from the rails commands.

    *Rafael Mendonça França*

*   Remove deprecated `capify!`.

    *Rafael Mendonça França*

*   Remove deprecated `config.secret_token`.

    *Rafael Mendonça França*

*   Seed database with inline ActiveJob job adapter.

    *Gannon McGibbon*

*   Add `rails db:system:change` command for changing databases.

    ```
    bin/rails db:system:change --to=postgresql
       force  config/database.yml
        gsub  Gemfile
    ```

    The change command copies a template `config/database.yml` with
    the target database adapter into your app, and replaces your database gem
    with the target database gem.

    *Gannon McGibbon*

*   Add `rails test:channels`.

    *bogdanvlviv*

*   Use original `bundler` environment variables during the process of generating a new rails project.

    *Marco Costa*

*   Send Active Storage analysis and purge jobs to dedicated queues by default.

    Analysis jobs now use the `:active_storage_analysis` queue, and purge jobs
    now use the `:active_storage_purge` queue. This matches Action Mailbox,
    which sends its jobs to dedicated queues by default.

    *George Claghorn*

*   Add `rails test:mailboxes`.

    *George Claghorn*

*   Introduce guard against DNS rebinding attacks.

    The `ActionDispatch::HostAuthorization` is a new middleware that prevents
    against DNS rebinding and other `Host` header attacks. It is included in
    the development environment by default with the following configuration:

        Rails.application.config.hosts = [
          IPAddr.new("0.0.0.0/0"), # All IPv4 addresses.
          IPAddr.new("::/0"),      # All IPv6 addresses.
          "localhost"              # The localhost reserved domain.
        ]

    In other environments `Rails.application.config.hosts` is empty and no
    `Host` header checks will be done. If you want to guard against header
    attacks on production, you have to manually permit the allowed hosts
    with:

        Rails.application.config.hosts << "product.com"

    The host of a request is checked against the `hosts` entries with the case
    operator (`#===`), which lets `hosts` support entries of type `Regexp`,
    `Proc` and `IPAddr` to name a few. Here is an example with a regexp.

        # Allow requests from subdomains like `www.product.com` and
        # `beta1.product.com`.
        Rails.application.config.hosts << /.*\.product\.com/

    A special case is supported that allows you to permit all sub-domains:

        # Allow requests from subdomains like `www.product.com` and
        # `beta1.product.com`.
        Rails.application.config.hosts << ".product.com"

    *Genadi Samokovarov*

*   Remove redundant suffixes on generated helpers.

    *Gannon McGibbon*

*   Remove redundant suffixes on generated integration tests.

    *Gannon McGibbon*

*   Fix boolean interaction in scaffold system tests.

    *Gannon McGibbon*

*   Remove redundant suffixes on generated system tests.

    *Gannon McGibbon*

*   Add an `abort_on_failure` boolean option to the generator method that shell
    out (`generate`, `rake`, `rails_command`) to abort the generator if the
    command fails.

    *David Rodríguez*

*   Remove `app/assets` and `app/javascript` from `eager_load_paths` and `autoload_paths`.

    *Gannon McGibbon*

*   Use Ids instead of memory addresses when displaying references in scaffold views.

    Fixes #29200.

    *Rasesh Patel*

*   Adds support for multiple databases to `rails db:migrate:status`.
    Subtasks are also added to get the status of individual databases (eg. `rails db:migrate:status:animals`).

    *Gannon McGibbon*

*   Use Webpacker by default to manage app-level JavaScript through the new app/javascript directory.
    Sprockets is now solely in charge, by default, of compiling CSS and other static assets.
    Action Cable channel generators will create ES6 stubs rather than use CoffeeScript.
    Active Storage, Action Cable, Turbolinks, and Rails-UJS are loaded by a new application.js pack.
    Generators no longer generate JavaScript stubs.

    *DHH*, *Lachlan Sylvester*

*   Add `database` (aliased as `db`) option to model generator to allow
    setting the database. This is useful for applications that use
    multiple databases and put migrations per database in their own directories.

    ```
    bin/rails g model Room capacity:integer --database=kingston
          invoke  active_record
          create    db/kingston_migrate/20180830151055_create_rooms.rb
    ```

    Because rails scaffolding uses the model generator, you can
    also specify a database with the scaffold generator.

    *Gannon McGibbon*

*   Raise an error when "recyclable cache keys" are being used by a cache store
    that does not explicitly support it. Custom cache keys that do support this feature
    can bypass this error by implementing the `supports_cache_versioning?` method on their
    class and returning a truthy value.

    *Richard Schneeman*

*   Support environment specific credentials overrides.

    So any environment will look for `config/credentials/#{Rails.env}.yml.enc` and fall back
    to `config/credentials.yml.enc`.

    The encryption key can be in `ENV["RAILS_MASTER_KEY"]` or `config/credentials/production.key`.

    Environment credentials overrides can be edited with `rails credentials:edit --environment production`.
    If no override is set up for the passed environment, it will be created.

    Additionally, the default lookup paths can be overwritten with these configs:

    - `config.credentials.content_path`
    - `config.credentials.key_path`

    *Wojciech Wnętrzak*

*   Make `ActiveSupport::Cache::NullStore` the default cache store in the test environment.

    *Michael C. Nelson*

*   Emit warning for unknown inflection rule when generating model.

    *Yoshiyuki Kinjo*

*   Add `database` (aliased as `db`) option to migration generator.

    If you're using multiple databases and have a folder for each database
    for migrations (ex db/migrate and db/new_db_migrate) you can now pass the
    `--database` option to the generator to make sure the the migration
    is inserted into the correct folder.

    ```
    rails g migration CreateHouses --database=kingston
      invoke  active_record
      create    db/kingston_migrate/20180830151055_create_houses.rb
    ```

    *Eileen M. Uchitelle*

*   Deprecate `rake routes` in favor of `rails routes`.

    *Yuji Yaginuma*

*   Deprecate `rake initializers` in favor of `rails initializers`.

    *Annie-Claude Côté*

*   Deprecate `rake dev:cache` in favor of `rails dev:cache`.

    *Annie-Claude Côté*

*   Deprecate `rails notes` subcommands in favor of passing an `annotations` argument to `rails notes`.

    The following subcommands are replaced by passing `--annotations` or `-a` to `rails notes`:
    - `rails notes:custom ANNOTATION=custom` is deprecated in favor of using `rails notes -a custom`.
    - `rails notes:optimize` is deprecated in favor of using `rails notes -a OPTIMIZE`.
    - `rails notes:todo` is deprecated in favor of  using`rails notes -a TODO`.
    - `rails notes:fixme` is deprecated in favor of using `rails notes -a FIXME`.

    *Annie-Claude Côté*

*   Deprecate `SOURCE_ANNOTATION_DIRECTORIES` environment variable used by `rails notes`
    through `Rails::SourceAnnotationExtractor::Annotation` in favor of using `config.annotations.register_directories`.

    *Annie-Claude Côté*

*   Deprecate `rake notes` in favor of `rails notes`.

    *Annie-Claude Côté*

*   Don't generate unused files in `app:update` task.

    Skip the assets' initializer when sprockets isn't loaded.

    Skip `config/spring.rb` when spring isn't loaded.

    Skip yarn's contents when yarn integration isn't used.

    *Tsukuru Tanimichi*

*   Make the master.key file read-only for the owner upon generation on
    POSIX-compliant systems.

    Previously:

        $ ls -l config/master.key
        -rw-r--r--   1 owner  group      32 Jan 1 00:00 master.key

    Now:

        $ ls -l config/master.key
        -rw-------   1 owner  group      32 Jan 1 00:00 master.key

    Fixes #32604.

    *Jose Luis Duran*

*   Deprecate support for using the `HOST` environment variable to specify the server IP.

    The `BINDING` environment variable should be used instead.

    Fixes #29516.

    *Yuji Yaginuma*

*   Deprecate passing Rack server name as a regular argument to `rails server`.

    Previously:

        $ bin/rails server thin

    There wasn't an explicit option for the Rack server to use, now we have the
    `--using` option with the `-u` short switch.

    Now:

        $ bin/rails server -u thin

    This change also improves the error message if a missing or mistyped rack
    server is given.

    *Genadi Samokovarov*

*   Add "rails routes --expanded" option to output routes in expanded mode like
    "psql --expanded". Result looks like:

    ```
    $ rails routes --expanded
    --[ Route 1 ]------------------------------------------------------------
    Prefix            | high_scores
    Verb              | GET
    URI               | /high_scores(.:format)
    Controller#Action | high_scores#index
    --[ Route 2 ]------------------------------------------------------------
    Prefix            | new_high_score
    Verb              | GET
    URI               | /high_scores/new(.:format)
    Controller#Action | high_scores#new
    ```

    *Benoit Tigeot*

*   Rails 6 requires Ruby 2.5.0 or newer.

    *Jeremy Daer*, *Kasper Timm Hansen*


Please check [5-2-stable](https://github.com/rails/rails/blob/5-2-stable/railties/CHANGELOG.md) for previous changes.
