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
