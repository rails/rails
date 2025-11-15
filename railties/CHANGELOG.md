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
