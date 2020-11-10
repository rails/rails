*   Add support for stylesheets and ERB views to `rails stats`.

    *Joel Hawksley*

*   Allow appended root routes to take precedence over internal welcome controller.

    *Gannon McGibbon*


## Rails 6.1.0.rc1 (November 02, 2020) ##

*   Added `Railtie#server` hook called when Rails starts a server.
    This is useful in case your application or a library needs to run
    another process next to the Rails server. This is quite common in development
    for instance to run the Webpack or the React server.

    It can be used like this:

    ```ruby
      class MyRailtie < Rails::Railtie
        server do
          WebpackServer.run
        end
      end
    ```

    *Edouard Chin*

*   Remove deprecated `rake dev:cache` tasks.

    *Rafael Mendonça França*

*   Remove deprecated `rake routes` tasks.

    *Rafael Mendonça França*

*   Remove deprecated `rake initializers` tasks.

    *Rafael Mendonça França*

*   Remove deprecated support for using the `HOST` environment variable to specify the server IP.

    *Rafael Mendonça França*

*   Remove deprecated `server` argument from the rails server command.

    *Rafael Mendonça França*

*   Remove deprecated `SOURCE_ANNOTATION_DIRECTORIES` environment variable support from `rails notes`.

    *Rafael Mendonça França*

*   Remove deprecated `connection` option in the `rails dbconsole` command.

    *Rafael Mendonça França*

*   Remove depreated `rake notes` tasks.

    *Rafael Mendonça França*

*   Return a 405 Method Not Allowed response when a request uses an unknown HTTP method.

    Fixes #38998.

    *Loren Norman*

*   Make railsrc file location xdg-specification compliant

    `rails new` will now look for the default `railsrc` file at
    `$XDG_CONFIG_HOME/rails/railsrc` (or `~/.config/rails/railsrc` if
    `XDG_CONFIG_HOME` is not set).  If this file does not exist, `rails new`
    will fall back to `~/.railsrc`.

    The fallback behaviour means this does not cause any breaking changes.

    *Nick Wolf*

*   Change the default logging level from :debug to :info to avoid inadvertent exposure of personally
    identifiable information (PII) in production environments.

    *Eric M. Payne*

*   Automatically generate abstract class when using multiple databases.

    When generating a scaffold for a multiple database application, Rails will now automatically generate the abstract class for the database when the database argument is passed. This abstract class will include the connection information for the writing configuration and any models generated for that database will automatically inherit from the abstract class.

    Usage:

    ```bash
    $ bin/rails generate scaffold Pet name:string --database=animals
    ```

    Will create an abstract class for the animals connection.

    ```ruby
    class AnimalsRecord < ApplicationRecord
      self.abstract_class = true

      connects_to database: { writing: :animals }
    end
    ```

    And generate a `Pet` model that inherits from the new `AnimalsRecord`:

    ```ruby
    class Pet < AnimalsRecord
    end
    ```

    If you already have an abstract class and it follows a different pattern than Rails defaults, you can pass a parent class with the database argument.

    ```bash
    $ bin/rails generate scaffold Pet name:string --database=animals --parent=SecondaryBase
    ```

    This will ensure the model inherits from the `SecondaryBase` parent instead of `AnimalsRecord`

    ```ruby
    class Pet < SecondaryBase
    end
    ```

    *Eileen M. Uchitelle*, *John Crepezzi*

*   Accept params from url to prepopulate the Inbound Emails form in Rails conductor.

    *Chris Oliver*

*   Create a new rails app using a minimal stack.

      `rails new cool_app --minimal`

    All the following are excluded from your minimal stack:

    - action_cable
    - action_mailbox
    - action_mailer
    - action_text
    - active_job
    - active_storage
    - bootsnap
    - jbuilder
    - spring
    - system_tests
    - turbolinks
    - webpack

    *Haroon Ahmed*, *DHH*

*   Add default ENV variable option with BACKTRACE to turn off backtrace cleaning when debugging framework code in the
    generated config/initializers/backtrace_silencers.rb.

      `BACKTRACE=1 ./bin/rails runner "MyClass.perform"`

    *DHH*

*   The autoloading guide for Zeitwerk mode documents how to autoload classes
    during application boot in a safe way.

    *Haroon Ahmed*, *Xavier Noria*

*   The `classic` autoloader starts its deprecation cycle.

    New Rails projects are strongly discouraged from using `classic`, and we recommend that existing projects running on `classic` switch to `zeitwerk` mode when upgrading. Please check the [_Upgrading Ruby on Rails_](https://guides.rubyonrails.org/upgrading_ruby_on_rails.html) guide for tips.

    *Xavier Noria*

*   Adds `rails test:all` for running all tests in the test directory.

    This runs all test files in the test directory, including system tests.

    *Niklas Häusele*

*   Add `config.generators.after_generate` for processing to generated files.

    Register a callback that will get called right after generators has finished.

    *Yuji Yaginuma*

*   Make test file patterns configurable via Environment variables

    This makes test file patterns configurable via two environment variables:
     `DEFAULT_TEST`, to configure files to test, and `DEFAULT_TEST_EXCLUDE`,
    to configure files to exclude from testing.

    These values were hardcoded before, which made it difficult to add
    new categories of tests that should not be executed by default (e.g:
    smoke tests).

    *Jorge Manrubia*

*   No longer include `rake rdoc` task when generating plugins.

    To generate docs, use the `rdoc lib` command instead.

    *Jonathan Hefner*

*   Allow relative paths with trailing slashes to be passed to `rails test`.

    *Eugene Kenny*

*   Add `rack-mini-profiler` gem to the default `Gemfile`.

    `rack-mini-profiler` displays performance information such as SQL time and flame graphs.
    It's enabled by default in development environment, but can be enabled in production as well.
    See the gem [README](https://github.com/MiniProfiler/rack-mini-profiler/blob/master/README.md) for information on how to enable it in production.

    *Osama Sayegh*

*   `rails stats` will now count TypeScript files toward JavaScript stats.

    *Joshua Cody*

*   Run `git init` when generating plugins.

    Opt out with `--skip-git`.

    *OKURA Masafumi*

*   Add benchmark generator.

    Introduce benchmark generator to benchmark Rails applications.

      `rails generate benchmark opt_compare`

    This creates a benchmark file that uses [`benchmark-ips`](https://github.com/evanphx/benchmark-ips).
    By default, two code blocks can be benchmarked using the `before` and `after` reports.

    You can run the generated benchmark file using:
      `ruby script/benchmarks/opt_compare.rb`

    *Kevin Jalbert*, *Gannon McGibbon*

*   Cache compiled view templates when running tests by default.

    When generating a new app without `--skip-spring`, caching classes is
    disabled in `environments/test.rb`. This implicitly disables caching
    view templates too. This change will enable view template caching by
    adding this to the generated `environments/test.rb`:

    ```ruby
    config.action_view.cache_template_loading = true
    ```

    *Jorge Manrubia*

*   Introduce middleware move operations.

    With this change, you no longer need to delete and reinsert a middleware to
    move it from one place to another in the stack:

    ```ruby
    config.middleware.move_before ActionDispatch::Flash, Magical::Unicorns
    ```

    This will move the `Magical::Unicorns` middleware before
    `ActionDispatch::Flash`. You can also move it after with:

    ```ruby
    config.middleware.move_after ActionDispatch::Flash, Magical::Unicorns
    ```

    *Genadi Samokovarov*

*   Generators that inherit from NamedBase respect `--force` option.

    *Josh Brody*

*   Allow configuration of eager_load behaviour for rake environment:

        config.rake_eager_load

    Defaults to `false` as per previous behaviour.

    *Thierry Joyal*

*   Ensure Rails migration generator respects system-wide primary key config.

    When rails is configured to use a specific primary key type:

    ```ruby
    config.generators do |g|
      g.orm :active_record, primary_key_type: :uuid
    end
    ```

    Previously:

    ```bash
    $ bin/rails g migration add_location_to_users location:references
    ```

    The references line in the migration would not have `type: :uuid`.
    This change causes the type to be applied appropriately.

    *Louis-Michel Couture*, *Dermot Haughey*

*   Deprecate `Rails::DBConsole#config`.

    `Rails::DBConsole#config` is deprecated without replacement. Use `Rails::DBConsole.db_config.configuration_hash` instead.

    *Eileen M. Uchitelle*, *John Crepezzi*

*   `Rails.application.config_for` merges shared configuration deeply.

    ```yaml
    # config/example.yml
    shared:
      foo:
        bar:
          baz: 1
    development:
      foo:
        bar:
          qux: 2
    ```

    ```ruby
    # Previously
    Rails.application.config_for(:example)[:foo][:bar] #=> { qux: 2 }

    # Now
    Rails.application.config_for(:example)[:foo][:bar] #=> { baz: 1, qux: 2 }
    ```

    *Yuhei Kiriyama*

*   Remove access to values in nested hashes returned by `Rails.application.config_for` via String keys.

    ```yaml
    # config/example.yml
    development:
      options:
        key: value
    ```

    ```ruby
    Rails.application.config_for(:example).options
    ```

    This used to return a Hash on which you could access values with String keys. This was deprecated in 6.0, and now doesn't work anymore.

    *Étienne Barrié*

*   Configuration files for environments (`config/environments/*.rb`) are
    now able to modify `autoload_paths`, `autoload_once_paths`, and
    `eager_load_paths`.

    As a consequence, applications cannot autoload within those files. Before, they technically could, but changes in autoloaded classes or modules had no effect anyway in the configuration because reloading does not reboot.

    Ways to use application code in these files:

    * Define early in the boot process a class that is not reloadable, from which the application takes configuration values that get passed to the framework.

        ```ruby
        # In config/application.rb, for example.
        require "#{Rails.root}/lib/my_app/config"

        # In config/environments/development.rb, for example.
        config.foo = MyApp::Config.foo
        ```

    * If the class has to be reloadable, then wrap the configuration code in a `to_prepare` block:

        ```ruby
        config.to_prepare do
          config.foo = MyModel.foo
        end
        ```

      That assigns the latest `MyModel.foo` to `config.foo` when the application boots, and each time there is a reload. But whether that has an effect or not depends on the configuration point, since it is not uncommon for engines to read the application configuration during initialization and set their own state from them. That process happens only on boot, not on reloads, and if that is how `config.foo` worked, resetting it would have no effect in the state of the engine.

    *Allen Hsu* & *Xavier Noria*

*   Support using environment variable to set pidfile.

    *Ben Thorner*


Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/railties/CHANGELOG.md) for previous changes.
