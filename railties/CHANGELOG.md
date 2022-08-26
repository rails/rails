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

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/railties/CHANGELOG.md) for previous changes.
