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
