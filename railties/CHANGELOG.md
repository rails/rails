*   Trying to set a config key with the same name of a method now raises:

    ```ruby
    config.load_defaults = 7.0
    # NoMethodError: Cannot assign to `load_defaults`, it is a configuration method
    ```

    *Xavier Noria*

*   Deprecate `secrets:edit/show` and remove `secrets:setup`

    `bin/rails secrets:setup` has been deprecated since Rails 5.2 in favor of
    credentials. This command has been removed.

    `bin/rails secrets:show` and `bin/rails secrets:edit` have been deprecated
    in favor of credentials.
    Run `bin/rails credentials:help` for more information

    *Petrik de Heus*

*   `bin/rails --help` will now list only framework and plugin commands. Rake
    tasks defined in `lib/tasks/*.rake` files will no longer be included. For a
    list of those tasks, use `rake -T`.

    *Jonathan Hefner*

*   Allow calling `bin/rails restart` outside of app directory.

    The following would previously fail with a "No Rakefile found" error.

    ```bash
    blog/bin/rails restart
    ```

    *Petrik de Heus*

*   Support prerelease rubies in Gemfile template if RubyGems version is 3.3.13 or higher.

    *Yasuo Honda*, *David Rodríguez*

*   Autoloading setup honors root directories manually set by the user.

    This is relevant for custom namespaces. For example, if you'd like classes
    and modules under `app/services` to be defined in the `Services` namespace
    without an extra `app/services/services` directory, this is now enough:

    ```ruby
    # config/initializers/autoloading.rb

    # The namespace has to exist.
    #
    # In this example we define the module on the spot. Could also be created
    # elsewhere and its definition loaded here with an ordinary `require`. In
    # any case, `push_dir` expects a class or module object.
    module Services; end

    Rails.autoloaders.main.push_dir("#{Rails.root}/app/services", namespace: Services)
    ```

    Check the autoloading guide for further details.

    *Xavier Noria*

*   Railties now requires the irb gem as a dependency, which means when you install Rails, irb will also
    be installed as a gem. Rails will then use the installed version of irb for its console instead of
    relying on Ruby's built-in version.
    This ensures that Rails has access to the most up-to-date and reliable version of irb for its console.

    *Stan Lo*

*   Use infinitive form for all rails command descriptions verbs.

    *Petrik de Heus*

*   Credentials commands (e.g. `bin/rails credentials:edit`) now respect
    `config.credentials.content_path` and `config.credentials.key_path` when set
    in `config/application.rb` or `config/environments/#{Rails.env}.rb`.

    Before:

      * `bin/rails credentials:edit` ignored `RAILS_ENV`, and would always edit
        `config/credentials.yml.enc`.

      * `bin/rails credentials:edit --environment foo` would create and edit
        `config/credentials/foo.yml.enc`.

      * If `config.credentials.content_path` or `config.credentials.key_path`
        was set, `bin/rails credentials:edit` could not be used to edit the
        credentials.  Editing credentials required using `bin/rails
        encrypted:edit path/to/credentials --key path/to/key`.

    After:

      * `bin/rails credentials:edit` will edit the credentials file that the app
        would load for the current `RAILS_ENV`.

      * `bin/rails credentials:edit` respects `config.credentials.content_path`
        and `config.credentials.key_path` when set in `config/application.rb`
        or `config/environments/#{Rails.env}.rb`.

      * `bin/rails credentials:edit --environment foo` will create and edit
        `config/credentials/foo.yml.enc` _if_ `config.credentials.content_path`
        has not been set for the `foo` environment.  Ultimately, it will edit
        the credentials file that the app would load for the `foo` environment.

    *Jonathan Hefner*

*   Add descriptions for non-Rake commands when running `rails -h`.

    *Petrik de Heus*

*   Show relevant commands when calling help

    When running `rails -h` or just `rails` outside a Rails application,
    Rails outputs all options for running the `rails new` command. This can be
    confusing to users when they probably want to see the common Rails commands.

    Instead, we should always show the common commands when running `rails -h`
    inside or outside a Rails application.

    As the relevant commands inside a Rails application differ from the
    commands outside an application, the help USAGE file has been split to
    show the most relevant commands for the context.

    *Petrik de Heus*

*   Add Rails::HealthController#show and map it to /up for newly generated applications.
    Load balancers and uptime monitors all need a basic endpoint to tell whether the app is up.
    This is a good starting point that'll work in many situations.

    *DHH*

*   Only use HostAuthorization middleware if `config.hosts` is not empty

    *Hartley McGuire*

*   Raise an exception when a `before_action`'s "only" or "except" filter
    options reference an action that doesn't exist. This will be enabled by
    default but can be overridden via config.

    ```
    # config/environments/production.rb
    config.action_controller.raise_on_missing_callback_actions = false
    ```

    *Jess Bees*

*   Use physical processor count as the default Puma worker count in production.
    This can be overridden by setting `ENV["WEB_CONCURRENCY"]` or editing the
    generated "config/puma.rb" directly.

    *DHH*

*   Add Docker files by default to new apps: Dockerfile, .dockerignore, bin/docker-entrypoint.
    These files can be skipped with `--skip-docker`. They're intended as a starting point for
    a production deploy of the application. Not intended for development (see Docked Rails for that).

    Example:

    ```
    docker build -t app .
    docker volume create app-storage
    docker run --rm -it -v app-storage:/rails/storage -p 3000:3000 --env RAILS_MASTER_KEY=<see config/master.key> app
    ```

    You can also start a console or a runner from this image:

    ```
    docker run --rm -it -v app-storage:/rails/storage --env RAILS_MASTER_KEY=<see config/master.key> app console
    ```

    To create a multi-platform image on Apple Silicon to deploy on AMD or Intel and push to Docker Hub for user/app:

    ```
    docker login -u <user>
    docker buildx create --use
    docker buildx build --push --platform=linux/amd64,linux/arm64 -t <user/image> .
    ```

    *DHH, Sam Ruby*

*   Add ENV["SECRET_KEY_BASE_DUMMY"] for starting production environment with a generated secret base key,
    which can be used to run tasks like `assets:precompile` without making the RAILS_MASTER_KEY available
    to the build process.

    Dockerfile layer example:

    ```
    RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile
    ```

    *DHH*

*   Show descriptions for all commands in Rails help

    When calling `rails help` most commands missed their description. We now
    show the same descriptions as shown in `rails -T`.

    *Petrik de Heus*

*   Always generate the storage/ directory with rails new to ensure there's a stable place to
    put permanent files, and a single mount point for containers to map. Then default sqlite3 databases
    to live there instead of db/, which is only meant for configuration, not data.

    *DHH*

*   Rails console now disables `IRB`'s autocompletion feature in production by default.

    Setting `IRB_USE_AUTOCOMPLETE=true` can override this default.

    *Stan Lo*

*   Add `config.precompile_filter_parameters`, which enables precompilation of
    `config.filter_parameters` using `ActiveSupport::ParameterFilter.precompile_filters`.
    Precompilation can improve filtering performance, depending on the quantity
    and types of filters.

    `config.precompile_filter_parameters` defaults to `true` for
    `config.load_defaults 7.1` and above.

    *Jonathan Hefner*

*   Add `after_routes_loaded` hook to `Rails::Railtie::Configuration` for
    engines to add a hook to be called after application routes have been
    loaded.

    ```ruby
    MyEngine.config.after_routes_loaded do
      # code that must happen after routes have been loaded
    end
    ```

    *Chris Salzberg*

*   Send 303 See Other status code back for the destroy action on newly generated
    scaffold controllers.

    *Tony Drake*

*   Add `Rails.application.deprecators` as a central point to manage deprecators
    for an application.

    Individual deprecators can be added and retrieved from the collection:

    ```ruby
    Rails.application.deprecators[:my_gem] = ActiveSupport::Deprecation.new("2.0", "MyGem")
    Rails.application.deprecators[:other_gem] = ActiveSupport::Deprecation.new("3.0", "OtherGem")
    ```

    And the collection's configuration methods affect all deprecators in the
    collection:

    ```ruby
    Rails.application.deprecators.debug = true

    Rails.application.deprecators[:my_gem].debug
    # => true
    Rails.application.deprecators[:other_gem].debug
    # => true
    ```

    Additionally, all deprecators in the collection can be silenced for the
    duration of a given block:

    ```ruby
    Rails.application.deprecators.silence do
      Rails.application.deprecators[:my_gem].warn    # => silenced (no warning)
      Rails.application.deprecators[:other_gem].warn # => silenced (no warning)
    end
    ```

    *Jonathan Hefner*

*   Move dbconsole logic to Active Record connection adapter.

    Instead of hosting the connection logic in the command object, the
    database adapter should be responsible for connecting to a console session.
    This patch moves #find_cmd_and_exec to the adapter and exposes a new API to
    lookup the adapter class without instantiating it.

    *Gannon McGibbon*, *Paarth Madan*

*   Add `Rails.application.message_verifiers` as a central point to configure
    and create message verifiers for an application.

    This allows applications to, for example, rotate old `secret_key_base`
    values:

    ```ruby
    config.before_initialize do |app|
      app.message_verifiers.rotate(secret_key_base: "old secret_key_base")
    end
    ```

    And for libraries to create preconfigured message verifiers:

    ```ruby
    ActiveStorage.verifier = Rails.application.message_verifiers["ActiveStorage"]
    ```

    *Jonathan Hefner*

*   Support MySQL's ssl-mode option for the dbconsole command.

    Verifying the identity of the database server requires setting the ssl-mode
    option to VERIFY_CA or VERIFY_IDENTITY. This option was previously ignored
    for the dbconsole command.

    *Petrik de Heus*

*   Delegate application record generator description to orm hooked generator.

    *Gannon McGibbon*

*   Show BCC recipients when present in Action Mailer previews.

    *Akshay Birajdar*

*   Extend `routes --grep` to also filter routes by matching against path.

    Example:

    ```
    > bin/rails routes --grep /cats/1
    Prefix Verb   URI Pattern         Controller#Action
       cat GET    /cats/:id(.:format) cats#show
           PATCH  /cats/:id(.:format) cats#update
           PUT    /cats/:id(.:format) cats#update
           DELETE /cats/:id(.:format) cats#destroy
    ```

    *Orhan Toy*

*   Improve `rails runner` output when given a file path that doesn't exist.

    *Tekin Suleyman*

*   `config.allow_concurrency = false` now use a `Monitor` instead of a `Mutex`

    This allows to enable `config.active_support.executor_around_test_case` even
    when `config.allow_concurrency` is disabled.

    *Jean Boussier*

*   Add `routes --unused` option to detect extraneous routes.

    Example:

    ```
    > bin/rails routes --unused

    Found 2 unused routes:

    Prefix Verb URI Pattern    Controller#Action
       one GET  /one(.:format) action#one
       two GET  /two(.:format) action#two
    ```

    *Gannon McGibbon*

*   Add `--parent` option to controller generator to specify parent class of job.

    Example:

    `bin/rails g controller admin/users --parent=admin_controller` generates:

    ```ruby
    class Admin::UsersController < AdminController
      # ...
    end
    ```

    *Gannon McGibbon*

*   In-app custom credentials templates are now supported.  When a credentials
    file does not exist, `rails credentials:edit` will now try to use
    `lib/templates/rails/credentials/credentials.yml.tt` to generate the
    credentials file, before falling back to the default template.

    This allows e.g. an open-source Rails app (which would not include encrypted
    credentials files in its repo) to include a credentials template, so that
    users who install the app will get a custom pre-filled credentials file when
    they run `rails credentials:edit`.

    *Jonathan Hefner*

*   Except for `dev` and `test` environments, newly generated per-environment
    credentials files (e.g. `config/credentials/production.yml.enc`) now include
    a `secret_key_base` for convenience, just as `config/credentials.yml.enc`
    does.

    *Jonathan Hefner*

*   `--no-*` options now work with the app generator's `--minimal` option, and
    are both comprehensive and precise.  For example:

    ```console
    $ rails new my_cool_app --minimal
    Based on the specified options, the following options will also be activated:

      --skip-active-job [due to --minimal]
      --skip-action-mailer [due to --skip-active-job, --minimal]
      --skip-active-storage [due to --skip-active-job, --minimal]
      --skip-action-mailbox [due to --skip-active-storage, --minimal]
      --skip-action-text [due to --skip-active-storage, --minimal]
      --skip-javascript [due to --minimal]
      --skip-hotwire [due to --skip-javascript, --minimal]
      --skip-action-cable [due to --minimal]
      --skip-bootsnap [due to --minimal]
      --skip-dev-gems [due to --minimal]
      --skip-system-test [due to --minimal]

    ...

    $ rails new my_cool_app --minimal --no-skip-active-storage
    Based on the specified options, the following options will also be activated:

      --skip-action-mailer [due to --minimal]
      --skip-action-mailbox [due to --minimal]
      --skip-action-text [due to --minimal]
      --skip-javascript [due to --minimal]
      --skip-hotwire [due to --skip-javascript, --minimal]
      --skip-action-cable [due to --minimal]
      --skip-bootsnap [due to --minimal]
      --skip-dev-gems [due to --minimal]
      --skip-system-test [due to --minimal]

    ...
    ```

    *Brad Trick* and *Jonathan Hefner*

*   Add `--skip-dev-gems` option to app generator to skip adding development
    gems (like `web-console`) to the Gemfile.

    *Brad Trick*

*   Skip Active Storage and Action Mailer if Active Job is skipped.

    *Étienne Barrié*

*   Correctly check if frameworks are disabled when running app:update.

    *Étienne Barrié* and *Paulo Barros*

*   Delegate model generator description to orm hooked generator.

    *Gannon McGibbon*

*   Execute `rails runner` scripts inside the executor.

    Enables error reporting, query cache, etc.

    *Jean Boussier*

*   Avoid booting in development then test for test tasks.

    Running one of the rails test subtasks (e.g. test:system, test:models) would
    go through Rake and cause the app to be booted twice. Now all the test:*
    subtasks are defined as Thor tasks and directly load the test environment.

    *Étienne Barrié*

*   Deprecate `Rails::Generators::Testing::Behaviour` in favor of `Rails::Generators::Testing::Behavior`.

    *Gannon McGibbon*

*   Allow configuration of logger size for local and test environments

    `config.log_file_size`

    Defaults to `100` megabytes.

    *Bernie Chiu*

*   Enroll new apps in decrypted diffs of credentials by default.  This behavior
    can be opted out of with the app generator's `--skip-decrypted-diffs` flag.

    *Jonathan Hefner*

*   Support declarative-style test name filters with `bin/rails test`.

    This makes it possible to run a declarative-style test such as:

    ```ruby
    class MyTest < ActiveSupport::TestCase
      test "does something" do
        # ...
      end
    end
    ```

    Using its declared name:

    ```bash
    $ bin/rails test test/my_test.rb -n "does something"
    ```

    Instead of having to specify its expanded method name:

    ```bash
    $ bin/rails test test/my_test.rb -n test_does_something
    ```

    *Jonathan Hefner*

*   Add `--js` and `--skip-javascript` options to `rails new`

    `--js` alias to `rails new --javascript ...`

    Same as `-j`, e.g. `rails new --js esbuild ...`

    `--skip-js` alias to `rails new --skip-javascript ...`

    Same as `-J`, e.g. `rails new --skip-js ...`

    *Dorian Marié*

*   Allow relative paths with leading dot slash to be passed to `rails test`.

    Fix `rails test ./test/model/post_test.rb` to run a single test file.

    *Shouichi Kamiya* and *oljfte*

*   Deprecate `config.enable_dependency_loading`. This flag addressed a limitation of the `classic` autoloader and has no effect nowadays. To fix this deprecation, please just delete the reference.

    *Xavier Noria*

*   Define `config.enable_reloading` to be `!config.cache_classes` for a more intuitive name. While `config.enable_reloading` and `config.reloading_enabled?` are preferred from now on, `config.cache_classes` is supported for backwards compatibility.

    *Xavier Noria*

*   Add JavaScript dependencies installation on bin/setup

    Add  `yarn install` to bin/setup when using esbuild, webpack, or rollout.

    *Carlos Ribeiro*

*   Use `controller_class_path` in `Rails::Generators::NamedBase#route_url`

    The `route_url` method now returns the correct path when generating
    a namespaced controller with a top-level model using `--model-name`.

    Previously, when running this command:

    ``` sh
    bin/rails generate scaffold_controller Admin/Post --model-name Post
    ```

    the comments above the controller action would look like:

    ``` ruby
    # GET /posts
    def index
      @posts = Post.all
    end
    ```

    afterwards, they now look like this:

    ``` ruby
    # GET /admin/posts
    def index
      @posts = Post.all
    end
    ```

    Fixes #44662.

    *Andrew White*

*   No longer add autoloaded paths to `$LOAD_PATH`.

    This means it won't be possible to load them with a manual `require` call, the class or module can be referenced instead.

    Reducing the size of `$LOAD_PATH` speed-up `require` calls for apps not using `bootsnap`, and reduce the
    size of the `bootsnap` cache for the others.

    *Jean Boussier*

*   Remove default `X-Download-Options` header

    This header is currently only used by Internet Explorer which
    will be discontinued in 2022 and since Rails 7 does not fully
    support Internet Explorer this header should not be a default one.

    *Harun Sabljaković*

*   Add .node-version files for Rails apps that use Node.js

    Node version managers that make use of this file:
      https://github.com/shadowspawn/node-version-usage#node-version-file-usage

    The generated Dockerfile will use the same node version.

    *Sam Ruby*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/railties/CHANGELOG.md) for previous changes.
