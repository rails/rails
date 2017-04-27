## Rails 5.1.0 (April 27, 2017) ##

*   Namespace error pages' CSS selectors to stop the styles from bleeding into other pages
    when using Turbolinks.

    *Jan Krutisch*

*   Raise a error when using a bad symlink

    Previously bad symlinks (where the link destination doesn't exist)
    would be silent ignored and lead to hard to diagnose problems as
    the non-existence isn't readily apparent.

    *Richard Schneeman*

*   Remove -j (--javascript) option from `rails new` command.

    *claudiob*

*   Specify form field ids when generating a scaffold.

    This makes sure that the labels are linked up with the fields. The
    regression was introduced when the template was switched to
    `form_with`.

    *Yves Senn*

*   Add `app:update` task to engines.

    *Yuji Yaginuma*

*   Avoid running system tests by default with the `bin/rails test`
    and `bin/rake test` commands since they may be expensive.

    Fixes #28286.

    *Robin Dupret*

*   Improve encryption for encrypted secrets.

    Switch to aes-128-gcm authenticated encryption. Also generate a random
    initialization vector for each encryption so the same input and key can
    generate different encrypted data.

    Double the encryption key entropy by properly extracting the underlying
    bytes from the hexadecimal seed key.

    NOTE: Since the encryption mechanism has been switched, you need to run
    this script to upgrade:

    https://gist.github.com/kaspth/bc37989c2f39a5642112f28b1d93f343

    *Stephen Touset*

*   Add encrypted secrets in `config/secrets.yml.enc`.

    Allow storing production secrets straight in the revision control system by
    encrypting them.

    Use `bin/rails secrets:setup` to opt-in by generating `config/secrets.yml.enc`
    for the secrets themselves and `config/secrets.yml.key` for the encryption key.

    Edit secrets with `bin/rails secrets:edit`.

    See `bin/rails secrets:setup --help` for more.

    *Kasper Timm Hansen*

*   Fix running multiple tests in one `rake` command

    e.g. `bin/rake test:models test:controllers`

    *Dominic Cleal*

*   Add option to configure Ruby's warning behaviour to test runner.

    *Yuji Yaginuma*

*   Initialize git repo when generating new app, if option `--skip-git`
    is not provided.

    *Dino Maric*

*   Install Byebug gem as default in Windows (mingw and x64_mingw) platform.

    *Junichi Ito*

*   Make every Rails command work within engines.

    *Sean Collins*, *Yuji Yaginuma*

*   Don't generate HTML/ERB templates for scaffold controller with `--api` flag.

    Fixes #27591.

    *Prathamesh Sonpatki*

*   Make `Rails.env` fall back to `development` when `RAILS_ENV` and `RACK_ENV` is an empty string.

    *Daniel Deng*

*   Remove deprecated `CONTROLLER` environment variable for `routes` task.

    *Rafael Mendonça França*

*   Remove deprecated tasks: `rails:update`, `rails:template`, `rails:template:copy`,
    `rails:update:configs` and `rails:update:bin`.

    *Rafael Mendonça França*

*   Remove deprecated file `rails/rack/debugger`.

    *Rafael Mendonça França*

*   Remove deprecated `config.serve_static_files`.

    *Rafael Mendonça França*

*   Remove deprecated `config.static_cache_control`.

    *Rafael Mendonça França*

*   The `log:clear` task clear all environments log files by default.

    *Yuji Yaginuma*

*   Add Webpack support in new apps via the --webpack option, which will delegate to the rails/webpacker gem.

    To generate a new app that has Webpack dependencies configured and binstubs for webpack and webpack-watcher:

      `rails new myapp --webpack`

    To generate a new app that has Webpack + React configured and an example intalled:

      `rails new myapp --webpack=react`

    *DHH*

*   Add Yarn support in new apps with a yarn binstub and package.json. Skippable via --skip-yarn option.

    *Liceth Ovalles*, *Guillermo Iguaran*, *DHH*

*   Removed jquery-rails from default stack, instead rails-ujs that is shipped
    with Action View is included as default UJS adapter.

    *Guillermo Iguaran*

*   The config file `secrets.yml` is now loaded in with all keys as symbols.
    This allows secrets files to contain more complex information without all
    child keys being strings while parent keys are symbols.

    *Isaac Sloan*

*   Add `:skip_sprockets` to `Rails::PluginBuilder::PASSTHROUGH_OPTIONS`

    *Tsukuru Tanimichi*

*   Add `--skip-coffee` option to `rails new`

    *Seunghwan Oh*

*   Allow the use of listen's 3.1.x branch

    *Esteban Santana Santana*

*   Run `Minitest.after_run` hooks when running `rails test`.

    *Michael Grosser*

*   Run `before_configuration` callbacks as soon as application constant
    inherits from `Rails::Application`.

    Fixes #19880.

    *Yuji Yaginuma*

*   A generated app should not include Uglifier with `--skip-javascript` option.

    *Ben Pickles*

*   Set session store to cookie store internally and remove the initializer from
    the generated app.

    *Prathamesh Sonpatki*

*   Set the server host using the `HOST` environment variable.

    *mahnunchik*

*   Add public API to register new folders for `rake notes`:

        config.annotations.register_directories('spec', 'features')

    *John Meehan*

*   Display name of the class defining the initializer along with the initializer
    name in the output of `rails initializers`.

    Before:
        disable_dependency_loading

    After:
        DemoApp::Application.disable_dependency_loading

    *ta1kt0me*

*   Do not run `bundle install` when generating a new plugin.

    Since bundler 1.12.0, the gemspec is validated so the `bundle install`
    command will fail just after the gem is created causing confusion to the
    users. This change was a bug fix to correctly validate gemspecs.

    *Rafael Mendonça França*

*   Ensure `/rails/info` routes match in development for apps with a catch-all globbing route.

    *Nicholas Firth-McCoy*

*   Added a shared section to `config/secrets.yml` that will be loaded for all environments.

    *DHH*

Please check [5-0-stable](https://github.com/rails/rails/blob/5-0-stable/railties/CHANGELOG.md) for previous changes.
