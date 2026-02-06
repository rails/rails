*   `Rails.app.revision` now checks `ENV["REVISION"]` before falling back to the `REVISION` file or git.

    *Jonathan Baker*

*   Detect JavaScript package manager from lockfiles in generators.

    Rails generators now automatically detect bun, pnpm, npm, or yarn by looking
    for project lockfiles instead of hardcoding `yarn`.

    *David Lowenfels*

*   Disable the Active Record query cache in the console by default when using the executor.

    The query cache is now off by default in the console. Pass `--query-cache` to enable it for the session.

    *Cam Allen*

*   Console `reload!` will reset the console's executor, when present.

    *Ben Sheldon*

*   Add `libvips` to generated `ci.yml`

    Conditionally adds `libvips` to `ci.yml`.

    *Steve Polito*

*   Add `Rails.app.revision` to provide a version identifier for error reporting, monitoring, cache keys, etc.

    ```ruby
    Rails.app.revision # => "3d31d593e6cf0f82fa9bd0338b635af2f30d627b"
    ```

    By default it looks for a `REVISION` file at the root of the application, if absent it tries to extract
    the revision from the local git repository.

    If none of that is adequate, it can be set in the application config:

    ```ruby
    # config/application.rb
    module MyApp
      class Application < Rails::Application
        config.revision = ENV["GIT_SHA"]
      end
    end
    ```

    *Abdelkader Boudih*, *Jean Boussier*

*   Add `Rails.app.creds` to provide combined access to credentials stored in either ENV or the encrypted credentials file,
    and in development also .env credentials. Provides a new require/option API for accessing these values. Examples:

    ```ruby
    Rails.app.creds.require(:db_host) # ENV.fetch("DB_HOST") || Rails.app.credentials.require(:db_host)
    Rails.app.creds.require(:aws, :access_key_id) # ENV.fetch("AWS__ACCESS_KEY_ID") || Rails.app.credentials.require(:aws, :access_key_id)
    Rails.app.creds.option(:cache_host) # ENV["CACHE_HOST"] || Rails.app.credentials.option(:cache_host)
    Rails.app.creds.option(:cache_host, default: "cache-host-1") # ENV["CACHE_HOST"] || Rails.app.credentials.option(:cache_host) || "cache-host-1"
    Rails.app.creds.option(:cache_host, default: -> { "cache-host-1" }) # ENV["CACHE_HOST"] || Rails.app.credentials.option(:cache_host) || "cache-host-1"
    ```

    It's also possible to assign your own combined configuration, if you need to use a different backend than just ENVs + encrypted files:

    ```ruby
    Rails.app.creds = ActiveSupport::CombinedConfiguration.new(Rails.app.envs, OnePasswordConfiguration.new)
    ```

    *DHH*

*   Add `Rails.app.dotenvs` to provide access to .env variables through symbol-based lookup with explicit methods
    for required and optional values. This is the same interface offered by #credentials and can be accessed in a combined manner via #creds.

    It supports both variable interpolation with ${VAR} and command interpolation with $(echo "hello"). Otherwise the same as `Rails.app.envs`.

    *DHH*

*   Add `Rails.app.envs` to provide access to ENV variables through symbol-based lookup with explicit methods
    for required and optional values. This is the same interface offered by #credentials and can be accessed in a combined manner via #creds.

    ```ruby
    Rails.app.envs.require(:db_password) # ENV,fetch("DB_PASSWORD")
    Rails.app.envs.require(:aws, :access_key_id) # ENV.fetch("AWS__ACCESS_KEY_ID")
    Rails.app.envs.option(:cache_host) # ENV["CACHE_HOST"]
    Rails.app.envs.option(:cache_host, default: "cache-host-1") # ENV.fetch("CACHE_HOST", "cache-host-1")
    Rails.app.envs.option(:cache_host, default: -> { HostProvider.cache }) # ENV.fetch("CACHE_HOST") { HostProvider.cache }
    ```

    *DHH*

*   Add `Rails.app` as alias for `Rails.application`. Particularly helpful when accessing nested accessors inside application code,
    like when using `Rails.app.credentials`.

    *DHH*

*   Remove duplicate unique index for token migrations

    *zzak*, *Dan Bota*

*   Do not clean directories directly under the application root with `Rails::BacktraceCleaner`

    Improved `Rails.backtrace_cleaner` so that most paths located directly under the application's root directory are no longer silenced.

    *alpaca-tc*

*   Add `Rails::CodeStatistics#register_extension` to register file extensions for `rails stats`

    ```ruby
    Rails::CodeStatistics.register_extension("txt")
    ```

    *Taketo Takashima*

*   Wrap console command with an executor by default

    This can be disabled with `-w` or `--skip_executor`, same as runner.

    *zzak*

*   Add a new internal route in development to respond to chromium devtools GET request.

    This allows the app folder to be easily connected as a workspace in chromium-based browsers.

    *coorasse*

*   Set `config.rake_eager_load` in generated test environment to match `config.eager_load` behavior in CI.

    This ensures eager loading works consistently in CI when rake tasks invoke the `:environment` task before tests run.

    *Trevor Turk*

*   Update the `.node-version` file conditionally generated for new applications to 22.21.1

    *Taketo Takashima*

*   Do not assume and force SSL in production by default when using Kamal, to allow for out of the box Kamal deployments.

    It is still recommended to assume and force SSL in production as soon as you can.

    *Jerome Dalbert*

*   Add environment config file existence check

    `Rails::Application` will raise an error if unable to load any environment file.

    *Daniel Niknam*

*   `Rails::Application::RoutesReloader` uses the configured `Rails.application.config.file_watcher`

    *Jan Grodowski*

*   Add structured event for Rails deprecations, when `config.active_support.deprecation` is set to `:notify`.

    *zzak*

*   Report unhandled exceptions to the Error Reporter when running rake tasks via Rails command.

    *Akimichi Tanei*

*   Show help hint when starting `bin/rails console`

    *Petrik de Heus*

*   Persist `/rails/info/routes` search query and results between page reloads.

    *Ryan Kulp*

*   Add `--update` option to the `bin/bundler-audit` script.

    *Julien ANNE*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/railties/CHANGELOG.md) for previous changes.
