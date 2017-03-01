## Rails 5.0.2 (March 01, 2017) ##

*   Fix running multiple tests in one `rake` command

    e.g. `bin/rake test:models test:controllers`

    *Dominic Cleal*

*   Don't generate HTML/ERB templates for scaffold controller with `--api` flag.

    Fixes #27591.

    *Prathamesh Sonpatki*

*   Make `Rails.env` fall back to `development` when `RAILS_ENV` and `RACK_ENV` is an empty string.

    *Daniel Deng*

*   Reset a new session directly after its creation in ActionDispatch::IntegrationTest#open_session

    Fixes Issue #22742

    *Tawan Sierek*


## Rails 5.0.1 (December 21, 2016) ##

*   No changes.


## Rails 5.0.1.rc2 (December 10, 2016) ##

*   No changes.


## Rails 5.0.1.rc1 (December 01, 2016) ##

*   Add `:skip_sprockets` to `Rails::PluginBuilder::PASSTHROUGH_OPTIONS`

    *Tsukuru Tanimichi*

*   Run `Minitest.after_run` hooks when running `rails test`.

    *Michael Grosser*

*   Run `before_configuration` callbacks as soon as application constant
    inherits from `Rails::Application`.

    Fixes #19880.

    *Yuji Yaginuma*

*   Do not run `bundle install` when generating a new plugin.

    Since bundler 1.12.0, the gemspec is validated so the `bundle install`
    command will fail just after the gem is created causing confusion to the
    users. This change was a bug fix to correctly validate gemspecs.

    *Rafael Mendonça França*

*   Ensure `/rails/info` routes match in development for apps with a catch-all globbing route.

    *Nicholas Firth-McCoy*


## Rails 5.0.0 (June 30, 2016) ##

*   Ensure `/rails/info` routes match in development for apps with a catch-all globbing route.

    *Nicholas Firth-McCoy*

*   Ensure `/rails/info` routes match in development for apps with a catch-all globbing route.

    *Nicholas Firth-McCoy*

*   Add `config/initializers/to_time_preserves_timezone.rb`, which tells
    Active Support to preserve the receiver's timezone when calling `to_time`.
    This matches the new behavior that will be part of Ruby 2.4.

    Fixes #24617.

    *Andrew White*

*   Make `rails restart` command work with Puma by passing the restart command
    which Puma can use to restart rails server.

    *Prathamesh Sonpatki*

*   The application generator writes a new file `config/spring.rb`, which tells
    Spring to watch additional common files.

    *Xavier Noria*

*   The tasks in the rails task namespace is deprecated in favor of app namespace.
    (e.g. `rails:update` and `rails:template` tasks is renamed to `app:update` and `app:template`.)

    *Ryo Hashimoto*

*   Enable HSTS with IncludeSudomains header for new applications.

    *Egor Homakov*, *Prathamesh Sonpatki*

*   Alias `rake` with `rails_command` in the Rails Application Templates API
    following Rails 5 convention of preferring "rails" to "rake" to run tasks.

    *claudiob*

*   Generate applications with an option to log to STDOUT in production
    using the environment variable `RAILS_LOG_TO_STDOUT`.

    *Richard Schneeman*

*   Change fail fast of `bin/rails test` interrupts run on error.

    *Yuji Yaginuma*

*   The application generator supports `--skip-listen` to opt-out of features
    that depend on the listen gem. As of this writing they are the evented file
    system monitor and the async plugin for spring.

*   The Gemfiles of new applications include spring-watcher-listen on Linux and
    Mac OS X (unless `--skip-spring`).

    *Xavier Noria*

*   New applications are generated with the evented file system monitor enabled
    on Linux and Mac OS X.

    *Xavier Noria*

*   Add dummy files for apple-touch-icon.png and apple-touch-icon.png.

    See #23427.

    *Alexey Zabelin*

*   Add `after_bundle` callbacks in Rails plugin templates.  Useful for allowing
    templates to perform actions that are dependent upon `bundle install`.

    *Ryan Manuel*

*   Bring back `TEST=` env for `rake test` task.

    *Yves Senn*

*   Specify log file names or all logs to clear `rake log:clear`

    Specify which logs to clear when using the `rake log:clear` task, e.g. `rake log:clear LOGS=test,staging`

    Clear all logs from log/*.log e.g. `rake log:clear LOGS=all`

    By default `rake log:clear` clears standard environment log files i.e. 'development,test,production'

    *Pramod Shinde*

*   Fix using `add_source` with a block after using `gem` in a custom generator.

    *Will Fisher*

*   Newly generated plugins get a `README.md` in Markdown.

    *Yuji Yaginuma*

*   The generated config file for the development environment includes a new
    config line, commented out, showing how to enable the evented file watcher.

    *Xavier Noria*

*   `config.debug_exception_response_format` configures the format used
    in responses when errors occur in development mode.

    Set `config.debug_exception_response_format` to render an HTML page with
    debug info (using the value `:default`) or render debug info preserving
    the response format (using the value `:api`).

    *Jorge Bejar*

*   Fix setting exit status code for rake test tasks. The exit status code
    was not set when tests were fired with `rake`. Now, it is being set and it matches
    behavior of running tests via `rails` command (`rails test`), so no matter if
    `rake test` or `rails test` command is used the exit code will be set.

    *Arkadiusz Fal*

*   Add Command infrastructure to replace rake.

    Also move `rake dev:cache` to new infrastructure. You'll need to use
    `rails dev:cache` to toggle development caching from now on.

    *Chuck Callebs*

*   Allow use of `minitest-rails` gem with Rails test runner.

    Fixes #22455.

    *Chris Kottom*

*   Add `bin/test` script to rails plugin.

    `bin/test` can use the same API as `bin/rails test`.

    *Yuji Yaginuma*

*   Make `static_index` part of the `config.public_file_server` config and
    call it `config.public_file_server.index_name`.

    *Yuki Nishijima*

*   Deprecate `config.serve_static_files` in favor of `config.public_file_server.enabled`.

    Unifies the static asset options under `config.public_file_server`.

    To upgrade, replace occurrences of:

    ```
    config.serve_static_files = # false or true
    ```

    in your environment files, with:

    ```
    config.public_file_server.enabled = # false or true
    ```

    *Kasper Timm Hansen*

*   Deprecate `config.static_cache_control` in favor of
    `config.public_file_server.headers`.

    To upgrade, replace occurrences of:

    ```
    config.static_cache_control = 'public, max-age=60'
    ```

    in your environment files, with:

    ```
    config.public_file_server.headers = {
      'Cache-Control' => 'public, max-age=60'
    }
    ```

    `config.public_file_server.headers` can set arbitrary headers, sent along when
    a response is delivered.

    *Yuki Nishijima*

*   Route generators are now idempotent.
    Running generators several times no longer require you to cleanup routes.rb.

    *Thiago Pinto*

*   Allow passing an environment to `config_for`.

    *Simon Eskildsen*

*   Allow `rake stats` to account for rake tasks in lib/tasks.

    *Kevin Deisz*

*   Added javascript to update the URL on mailer previews with the currently
    selected email format. Reloading the page now keeps you on your selected
    format rather than going back to the default html version.

    *James Kerr*

*   Add fail fast to `bin/rails test`.

    Adding `--fail-fast` or `-f` when running tests will interrupt the run on
    the first failure:

    ```
    # Running:

    ................................................S......E

    ArgumentError: Wups! Bet you didn't expect this!
        test/models/bunny_test.rb:19:in `block in <class:BunnyTest>'

    bin/rails test test/models/bunny_test.rb:18

    ....................................F

    This failed

    bin/rails test test/models/bunny_test.rb:14

    Interrupted. Exiting...


    Finished in 0.051427s, 1808.3872 runs/s, 1769.4972 assertions/s.

    ```

    Note that any unexpected errors don't abort the run.

    *Kasper Timm Hansen*

*   Add inline output to `bin/rails test`.

    Any failures or errors (and skips if running in verbose mode) are output
    during a test run:

    ```
    # Running:

    .....S..........................................F

    This failed

    bin/rails test test/models/bunny_test.rb:14

    .................................E

    ArgumentError: Wups! Bet you didn't expect this!
        test/models/bunny_test.rb:19:in `block in <class:BunnyTest>'

    bin/rails test test/models/bunny_test.rb:18

    ....................

    Finished in 0.069708s, 1477.6019 runs/s, 1448.9106 assertions/s.
    ```

    Output can be deferred to after a run with the `--defer-output` option.

    *Kasper Timm Hansen*

*   Fix displaying mailer previews on non local requests when config
    `config.action_mailer.show_previews` is set.

    *Wojciech Wnętrzak*

*   `rails server` will now honour the `PORT` environment variable

    *David Cornu*

*   Plugins generated using `rails plugin new` are now generated with the
    version number set to 0.1.0.

    *Daniel Morris*

*   `I18n.load_path` is now reloaded under development so there's no need to
    restart the server to make new locale files available. Also, I18n will no
    longer raise for deleted locale files.

    *Kir Shatrov*

*   Add `bin/update` script to update development environment automatically.

    *Mehmet Emin İNAÇ*

*   Fix STATS_DIRECTORIES already defined warning when running rake from within
    the top level directory of an engine that has a test app.

    Fixes #20510.

    *Ersin Akinci*

*   Make enabling or disabling caching in development mode possible with
    `rake dev:cache`.

    Running `rake dev:cache` will create or remove tmp/caching-dev.txt. When this
    file exists `config.action_controller.perform_caching` will be set to true in
    config/environments/development.rb.

    Additionally, a server can be started with either `--dev-caching` or
    `--no-dev-caching` included to toggle caching on startup.

    *Jussi Mertanen*, *Chuck Callebs*

*   Add a `--api` option in order to generate plugins that can be added
    inside an API application.

    *Robin Dupret*

*   Fix `NoMethodError` when generating a scaffold inside a full engine.

    *Yuji Yaginuma*

*   Adding support for passing a block to the `add_source` action of a custom generator.

    *Mike Dalton*, *Hirofumi Wakasugi*

*   `assert_file` now understands paths with special characters
    (eg. `v0.1.4~alpha+nightly`).

    *Diego Carrion*

*   Remove ContentLength middleware from the defaults.  If you want it, just
    add it as a middleware in your config.

    *Egg McMuffin*

*   Make it possible to customize the executable inside rerun snippets.

    *Yves Senn*

*   Add support for API only apps.
    Middleware stack was slimmed down and it has only the needed
    middleware for API apps & generators generates the right files,
    folders and configurations.

    *Santiago Pastorino*, *Jorge Bejar*

*   Make generated scaffold functional tests work inside engines.

    *Yuji Yaginuma*

*   Generate a `.keep` file in the `tmp` folder by default as many scripts
    assume the existence of this folder and most would fail if it is absent.

    See #20299.

    *Yoong Kang Lim*, *Sunny Juneja*

*   `config.static_index` configures directory `index.html` filename

    Set `config.static_index` to serve a static directory index file not named
    `index`. E.g. to serve `main.html` instead of `index.html` for directory
    requests, set `config.static_index` to `"main"`.

    *Eliot Sykes*

*   `bin/setup` uses built-in rake tasks (`log:clear`, `tmp:clear`).

    *Mohnish Thallavajhula*

*   Fix mailer previews with attachments by using the mail gem's own API to
    locate the first part of the correct mime type.

    Fixes #14435.

    *Andrew White*

*   Remove sqlite support from `rails dbconsole`.

    *Andrew White*

*   Rename `railties/bin` to `railties/exe` to match the new Bundler executables
    convention.

    *Islam Wazery*

*   Print `bundle install` output in `rails new` as soon as it's available.

    Running `rails new` will now print the output of `bundle install` as
    it is available, instead of waiting until all gems finish installing.

    *Max Holder*

*   Respect `pluralize_table_names` when generating fixture file.

    Fixes #19519.

    *Yuji Yaginuma*

*   Add a new-line to the end of route method generated code.

    We need to add a `\n`, because we cannot have two routes
    in the same line.

    *arthurnn*

*   Add `rake initializers`.

    This task prints out all defined initializers in the order they are invoked
    by Rails. This is helpful for debugging issues related to the initialization
    process.

    *Naoto Kaneko*

*   Created rake restart task. Restarts your Rails app by touching the
    `tmp/restart.txt`.

    See #18876.

    *Hyonjee Joo*

*   Add `config/initializers/active_record_belongs_to_required_by_default.rb`.

    Newly generated Rails apps have a new initializer called
    `active_record_belongs_to_required_by_default.rb` which sets the value of
    the configuration option `config.active_record.belongs_to_required_by_default`
    to `true` when ActiveRecord is not skipped.

    As a result, new Rails apps require `belongs_to` association on model
    to be valid.

    This initializer is *not* added when running `rake rails:update`, so
    old apps ported to Rails 5 will work without any change.

    *Josef Šimánek*

*   `delete` operations in configurations are run last in order to eliminate
    'No such middleware' errors when `insert_before` or `insert_after` are added
    after the `delete` operation for the middleware being deleted.

    Fixes #16433.

    *Guo Xiang Tan*

*   Newly generated applications get a `README.md` in Markdown.

    *Xavier Noria*

*   Remove the documentation tasks `doc:app`, `doc:rails`, and `doc:guides`.

    *Xavier Noria*

*   Force generated routes to be inserted into `config/routes.rb`.

    *Andrew White*

*   Don't remove all line endings from `config/routes.rb` when revoking scaffold.

    Fixes #15913.

    *Andrew White*

*   Rename `--skip-test-unit` option to `--skip-test` in app generator

    *Melanie Gilman*

*   Add the `method_source` gem to the default Gemfile for apps.

    *Sean Griffin*

*   Drop old test locations from `rake stats`:

    - test/functional
    - test/unit

    *Ravil Bayramgalin*

*   Update `rake stats` to  correctly count declarative tests
    as methods in `_test.rb` files.

    *Ravil Bayramgalin*

*   Remove deprecated `test:all` and `test:all:db` tasks.

    *Rafael Mendonça França*

*   Remove deprecated `Rails::Rack::LogTailer`.

    *Rafael Mendonça França*

*   Remove deprecated `RAILS_CACHE` constant.

    *Rafael Mendonça França*

*   Remove deprecated `serve_static_assets` configuration.

    *Rafael Mendonça França*

*   Use local variables in `_form.html.erb` partial generated by scaffold.

    *Andrew Kozlov*

*   Add `config/initializers/callback_terminator.rb`.

    Newly generated Rails apps have a new initializer called
    `callback_terminator.rb` which sets the value of the configuration option
    `ActiveSupport.halt_callback_chains_on_return_false` to `false`.

    As a result, new Rails apps do not halt Active Record and Active Model
    callback chains when a callback returns `false`; only when they are
    explicitly halted with `throw(:abort)`.

    The terminator is *not* added when running `rake rails:update`, so returning
    `false` will still work on old apps ported to Rails 5, displaying a
    deprecation warning to prompt users to update their code to the new syntax.

    *claudiob*

*   Generated fixtures won't use the id when generated with references attributes.

    *Pablo Olmos de Aguilera Corradini*

*   Add `--skip-action-mailer` option to the app generator.

    *claudiob*

*   Autoload any second level directories called `app/*/concerns`.

    *Alex Robbin*

Please check [4-2-stable](https://github.com/rails/rails/blob/4-2-stable/railties/CHANGELOG.md) for previous changes.
