## Rails 7.2.1 (August 22, 2024) ##

*   Fix `rails console` for application with non default application constant.

    The wrongly assumed the Rails application would be named `AppNamespace::Application`,
    which is the default but not an obligation.

    *Jean Boussier*

*   Fix the default Dockerfile to include the full sqlite3 package.

    Prior to this it only included `libsqlite3`, so it wasn't enough to
    run `rails dbconsole`.

    *Jerome Dalbert*

*   Don't update public directory during `app:update` command for API-only Applications.

    *y-yagi*

*   Don't add bin/brakeman if brakeman is not in bundle when upgrading an application.

    *Etienne Barrié*

*   Remove PWA views and routes if its an API only project.

    *Jean Boussier*

*   Simplify generated Puma configuration

    *DHH*, *Rafael Mendonça França*


## Rails 7.2.0 (August 09, 2024) ##

*   The new `bin/rails boot` command boots the application and exits. Supports the
    standard `-e/--environment` options.

    *Xavier Noria*

*   Create a Dev Container Generator that generates a Dev Container setup based on the current configuration
    of the application. Usage:

    `bin/rails devcontainer`

    *Andrew Novoselac*

*   Add Rubocop and GitHub Actions to plugin generator.
    This can be skipped using --skip-rubocop and --skip-ci.

    *Chris Oliver*

*   Remove support for `oracle`, `sqlserver` and JRuby specific database adapters from the
    `rails new` and `rails db:system:change` commands.

    The supported options are `sqlite3`, `mysql`, `postgresql` and `trilogy`.

    *Andrew Novoselac*

*   Add options to `bin/rails app:update`.

    `bin/rails app:update` now supports the same generic options that generators do:

    * `--force`: Accept all changes to existing files
    * `--skip`: Refuse all changes to existing files
    * `--pretend`: Don't make any changes
    * `--quiet`: Don't output all changes made

    *Étienne Barrié*

*   Implement Rails console commands and helpers with IRB v1.13's extension APIs.

    Rails console users will now see `helper`, `controller`, `new_session`, and `app` under
    IRB help message's `Helper methods` category. And `reload!` command will be displayed under
    the new `Rails console` commands category.

    Prior to this change, Rails console's commands and helper methods are added through IRB's
    private components and don't show up in its help message, which led to poor discoverability.

    *Stan Lo*

*   Remove deprecated `Rails::Generators::Testing::Behaviour`.

    *Rafael Mendonça França*

*   Remove deprecated `find_cmd_and_exec` console helper.

    *Rafael Mendonça França*

*   Remove deprecated `Rails.config.enable_dependency_loading`.

    *Rafael Mendonça França*

*   Remove deprecated `Rails.application.secrets`.

    *Rafael Mendonça França*

*   Generated Gemfile will include `require: "debug/prelude"` for the `debug` gem.

    Requiring `debug` gem directly automatically activates it, which could introduce
    additional overhead and memory usage even without entering a debugging session.

    By making Bundler require `debug/prelude` instead, developers can keep their access
    to breakpoint methods like `debugger` or `binding.break`, but the debugger won't be
    activated until a breakpoint is hit.

    *Stan Lo*

*   Skip generating a `test` job in ci.yml when a new application is generated with the
    `--skip-test` option.

    *Steve Polito*

*   Update the `.node-version` file conditionally generated for new applications to 20.11.1

    *Steve Polito*

*   Fix sanitizer vendor configuration in 7.1 defaults.

    In apps where rails-html-sanitizer was not eagerly loaded, the sanitizer default could end up
    being Rails::HTML4::Sanitizer when it should be set to Rails::HTML5::Sanitizer.

    *Mike Dalessio*, *Rafael Mendonça França*

*   Set `action_mailer.default_url_options` values in `development` and `test`.

    Prior to this commit, new Rails applications would raise `ActionView::Template::Error`
    if a mailer included a url built with a `*_path` helper.

    *Steve Polito*

*   Introduce `Rails::Generators::Testing::Assertions#assert_initializer`.

    Compliments the existing `initializer` generator action.

    ```rb
    assert_initializer "mail_interceptors.rb"
    ```

    *Steve Polito*

*   Generate a .devcontainer folder and its contents when creating a new app.

    The .devcontainer folder includes everything needed to boot the app and do development in a remote container.

    The container setup includes:
     - A redis container for Kredis, ActionCable etc.
     - A database (SQLite, Postgres, MySQL or MariaDB)
     - A Headless chrome container for system tests
     - Active Storage configured to use the local disk and with preview features working

    If any of these options are skipped in the app setup they will not be included in the container configuration.

    These files can be skipped using the `--skip-devcontainer` option.

    *Andrew Novoselac & Rafael Mendonça França*

*   Introduce `SystemTestCase#served_by` for configuring the System Test application server.

    By default this is localhost. This method allows the host and port to be specified manually.

    ```ruby
    class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
      served_by host: "testserver", port: 45678
    end
    ```

    *Andrew Novoselac & Rafael Mendonça França*

*   `bin/rails test` will no longer load files named `*_test.rb` if they are located in the `fixtures` folder.

    *Edouard Chin*

*   Ensure logger tags configured with `config.log_tags` are still active in `request.action_dispatch` handlers.

    *KJ Tsanaktsidis*

*   Setup jemalloc in the default Dockerfile for memory optimization.

    *Matt Almeida*, *Jean Boussier*

*   Commented out lines in .railsrc file should not be treated as arguments when using
    rails new generator command. Update ARGVScrubber to ignore text after `#` symbols.

    *Willian Tenfen*

*   Skip CSS when generating APIs.

    *Ruy Rocha*

*   Rails console now indicates application name and the current Rails environment:

    ```txt
    my-app(dev)> # for RAILS_ENV=development
    my-app(test)> # for RAILS_ENV=test
    my-app(prod)> # for RAILS_ENV=production
    my-app(my_env)> # for RAILS_ENV=my_env
    ```

    The application name is derived from the application's module name from `config/application.rb`.
    For example, `MyApp` will displayed as `my-app` in the prompt.

    Additionally, the environment name will be colorized when the environment is
    `development` (blue), `test` (blue), or `production` (red), if your
    terminal supports it.

    *Stan Lo*

*   Ensure `autoload_paths`, `autoload_once_paths`, `eager_load_paths`, and
    `load_paths` only have directories when initialized from engine defaults.

    Previously, files under the `app` directory could end up there too.

    *Takumasa Ochi*

*   Prevent unnecessary application reloads in development.

    Previously, some files outside autoload paths triggered unnecessary reloads.
    With this fix, application reloads according to `Rails.autoloaders.main.dirs`,
    thereby preventing unnecessary reloads.

    *Takumasa Ochi*

*   Use `oven-sh/setup-bun` in GitHub CI when generating an app with Bun.

    *TangRufus*

*   Disable `pidfile` generation in the `production` environment.

    *Hans Schnedlitz*

*   Set `config.action_view.annotate_rendered_view_with_filenames` to `true` in
    the `development` environment.

    *Adrian Marin*

*   Support the `BACKTRACE` environment variable to turn off backtrace cleaning.

    Useful for debugging framework code:

    ```sh
    BACKTRACE=1 bin/rails server
    ```

    *Alex Ghiculescu*

*   Raise `ArgumentError` when reading `config.x.something` with arguments:

    ```ruby
    config.x.this_works.this_raises true # raises ArgumentError
    ```

    *Sean Doyle*

*   Add default PWA files for manifest and service-worker that are served from `app/views/pwa` and can be dynamically rendered through ERB. Mount these files explicitly at the root with default routes in the generated routes file.

    *DHH*

*   Updated system tests to now use headless Chrome by default for the new applications.

    *DHH*

*   Add GitHub CI files for Dependabot, Brakeman, RuboCop, and running tests by default. Can be skipped with `--skip-ci`.

    *DHH*

*   Add Brakeman by default for static analysis of security vulnerabilities. Allow skipping with `--skip-brakeman option`.

    *vipulnsward*

*   Add RuboCop with rules from `rubocop-rails-omakase` by default. Skip with `--skip-rubocop`.

    *DHH* and *zzak*

*   Use `bin/rails runner --skip-executor` to not wrap the runner script with an
    Executor.

    *Ben Sheldon*

*   Fix isolated engines to take `ActiveRecord::Base.table_name_prefix` into consideration.

    This will allow for engine defined models, such as inside Active Storage, to respect
    Active Record table name prefix configuration.

    *Chedli Bourguiba*

*   Fix running `db:system:change` when the app has no Dockerfile.

    *Hartley McGuire*

*   In Action Mailer previews, list inline attachments separately from normal
    attachments.

    For example, attachments that were previously listed like

      > Attachments: logo.png file1.pdf file2.pdf

    will now be listed like

      > Attachments: file1.pdf file2.pdf (Inline: logo.png)

    *Christian Schmidt* and *Jonathan Hefner*

*   In mailer preview, only show SMTP-To if it differs from the union of To, Cc and Bcc.

    *Christian Schmidt*

*   Enable YJIT by default on new applications running Ruby 3.3+.

    This can be disabled by setting `Rails.application.config.yjit = false`

    *Jean Boussier*, *Rafael Mendonça França*

*   In Action Mailer previews, show date from message `Date` header if present.

    *Sampat Badhe*

*   Exit with non-zero status when the migration generator fails.

    *Katsuhiko YOSHIDA*

*   Use numeric UID and GID in Dockerfile template.

    The Dockerfile generated by `rails new` sets the default user and group
    by name instead of UID:GID. This can cause the following error in Kubernetes:

    ```
    container has runAsNonRoot and image has non-numeric user (rails), cannot verify user is non-root
    ```

    This change sets default user and group by their numeric values.

    *Ivan Fedotov*

*   Disallow invalid values for rails new options.

    The `--database`, `--asset-pipeline`, `--css`, and `--javascript` options
    for `rails new` take different arguments. This change validates them.

    *Tony Drake*, *Akhil G Krishnan*, *Petrik de Heus*

*   Conditionally print `$stdout` when invoking `run_generator`.

    In an effort to improve the developer experience when debugging
    generator tests, we add the ability to conditionally print `$stdout`
    instead of capturing it.

    This allows for calls to `binding.irb` and `puts` work as expected.

    ```sh
    RAILS_LOG_TO_STDOUT=true ./bin/test test/generators/actions_test.rb
    ```

    *Steve Polito*

*   Remove the option `config.public_file_server.enabled` from the generators
    for all environments, as the value is the same in all environments.

    *Adrian Hirt*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/railties/CHANGELOG.md) for previous changes.
