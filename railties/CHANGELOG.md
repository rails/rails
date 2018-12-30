*   Add `rails test:mailboxes`.

    *George Claghorn*

*   Introduce guard against DNS rebinding attacks

    The `ActionDispatch::HostAuthorization` is a new middleware that prevent
    against DNS rebinding and other `Host` header attacks. It is included in
    the development environment by default with the following configuration:

        Rails.application.config.hosts = [
          IPAddr.new("0.0.0.0/0"), # All IPv4 addresses.
          IPAddr.new("::/0"),      # All IPv6 addresses.
          "localhost"              # The localhost reserved domain.
        ]

    In other environments `Rails.application.config.hosts` is empty and no
    `Host` header checks will be done. If you want to guard against header
    attacks on production, you have to manually whitelist the allowed hosts
    with:

        Rails.application.config.hosts << "product.com"

    The host of a request is checked against the `hosts` entries with the case
    operator (`#===`), which lets `hosts` support entries of type `RegExp`,
    `Proc` and `IPAddr` to name a few. Here is an example with a regexp.

        # Allow requests from subdomains like `www.product.com` and
        # `beta1.product.com`.
        Rails.application.config.hosts << /.*\.product\.com/

    A special case is supported that allows you to whitelist all sub-domains:

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

*   Add JSON support to rails properties route (`/rails/info/properties`).

    Now, `Rails::Info` properties may be accessed in JSON format at `/rails/info/properties.json`.

    *Yoshiyuki Hirano*

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

*   Support environment specific credentials file.

    For `production` environment look first for `config/credentials/production.yml.enc` file that can be decrypted by
    `ENV["RAILS_MASTER_KEY"]` or `config/credentials/production.key` master key.
    Edit given environment credentials file by command `rails credentials:edit --environment production`.
    Default paths can be overwritten by setting `config.credentials.content_path` and `config.credentials.key_path`.

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

*   Deprecate support for using the `HOST` environment to specify the server IP.

    The `BINDING` environment should be used instead.

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
