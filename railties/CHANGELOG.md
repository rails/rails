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

    ```
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
