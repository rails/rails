## Rails 5.2.1.1 (November 27, 2018) ##

*   No changes.


## Rails 5.2.1 (August 07, 2018) ##

*   Respect `NODE_ENV` when running `rails yarn:install`.

    *Max Melentiev*

*   Don't generate unused files in `app:update` task

     Skip the assets' initializer when sprockets isn't loaded.

     Skip `config/spring.rb` when spring isn't loaded.

    *Tsukuru Tanimichi*

*   Don't include `bootsnap` by default in apps generated under JRuby.

    Fixes #32641.

    *Guillermo Iguaran*

*   Create the `.ruby-version` file compatible with MRI/JRuby by default.

    Fixes #32639.

    *Guillermo Iguaran*

*   Make the master.key file read-only for the owner upon generation on
    POSIX-compliant systems.

    Previously:

        $ ls -l config/master.key
        -rw-r--r--   1 owner  group      32 Jan 1 00:00 master.key

    Now:

        $ ls -l config/master.key
        -rw-------   1 owner  group      32 Jan 1 00:00 master.key

    Fixes #32604.

    *Jose Luis Duran*

*   Allow use of `minitest-rails` gem with Rails test runner.

    Fixes #31324.

    *Yuji Yaginuma*


## Rails 5.2.0 (April 09, 2018) ##

*   Fix minitest rails plugin.

    The custom reporters are added only if needed.

    This will fix conflicts with others plugins.

    *Kevin Robatel*

*   Deprecate `after_bundle` callback in Rails plugin templates.

    *Yuji Yaginuma*

*   `rails new` and `rails plugin new` get `Active Storage` by default.
     Add ability to skip `Active Storage` with `--skip-active-storage`
     and do so automatically when `--skip-active-record` is used.

    *bogdanvlviv*

*   Gemfile for new apps: upgrade redis-rb from ~> 3.0 to 4.0.

    *Jeremy Daer*

*   Add `mini_magick` to default `Gemfile` as comment.

    *Yoshiyuki Hirano*

*   Derive `secret_key_base` from the app name in development and test environments.

    Spares away needless secret configs.

    *DHH*, *Kasper Timm Hansen*

*   Support multiple versions arguments for `gem` method of Generators.

    *Yoshiyuki Hirano*

*   Add `--skip-yarn` option to the plugin generator.

    *bogdanvlviv*

*   Optimize routes indentation.

    *Yoshiyuki Hirano*

*   Optimize indentation for generator actions.

    *Yoshiyuki Hirano*

*   Skip unused components when running `bin/rails` in Rails plugin.

    *Yoshiyuki Hirano*

*   Add `git_source` to `Gemfile` for plugin generator.

    *Yoshiyuki Hirano*

*   Add `--skip-action-cable` option to the plugin generator.

    *bogdanvlviv*

*   Deprecate support for using a `Rails::Application` subclass to start Rails server.

    *Yuji Yaginuma*

*   Add `ruby x.x.x` version to `Gemfile` and create `.ruby-version`
    root file containing the current Ruby version when new Rails applications are
    created.

    *Alberto Almagro*

*   Support `-` as a platform-agnostic way to run a script from stdin with
    `rails runner`

    *Cody Cutrer*

*   Add `bootsnap` to default `Gemfile`.

    *Burke Libbey*

*   Properly expand shortcuts for environment's name running the `console`
    and `dbconsole` commands.

    *Robin Dupret*

*   Passing the environment's name as a regular argument to the
    `rails dbconsole` and `rails console` commands is deprecated.
    The `-e` option should be used instead.

    Previously:

        $ bin/rails dbconsole production

    Now:

        $ bin/rails dbconsole -e production

    *Robin Dupret*, *Kasper Timm Hansen*

*   Allow passing a custom connection name to the `rails dbconsole`
    command when using a 3-level database configuration.

        $ bin/rails dbconsole -c replica

    *Robin Dupret*, *Jeremy Daer*

*   Skip unused components when running `bin/rails app:update`.

    If the initial app generation skipped Action Cable, Active Record etc.,
    the update task honors those skips too.

    *Yuji Yaginuma*

*   Make Rails' test runner work better with minitest plugins.

    By demoting the Rails test runner to just another minitest plugin —
    and thereby not eager loading it — we can co-exist much better with
    other minitest plugins such as pride and minitest-focus.

    *Kasper Timm Hansen*

*   Load environment file in `dbconsole` command.

    Fixes #29717.

    *Yuji Yaginuma*

*   Add `rails secrets:show` command.

    *Yuji Yaginuma*

*   Allow mounting the same engine several times in different locations.

    Fixes #20204.

    *David Rodríguez*

*   Clear screenshot files in `tmp:clear` task.

    *Yuji Yaginuma*

*   Add `railtie.rb` to the plugin generator

    *Tsukuru Tanimichi*

*   Deprecate `capify!` method in generators and templates.

    *Yuji Yaginuma*

*   Allow irb options to be passed from `rails console` command.

    Fixes #28988.

    *Yuji Yaginuma*

*   Added a shared section to `config/database.yml` that will be loaded for all environments.

    *Pierre Schambacher*

*   Namespace error pages' CSS selectors to stop the styles from bleeding into other pages
    when using Turbolinks.

    *Jan Krutisch*


Please check [5-1-stable](https://github.com/rails/rails/blob/5-1-stable/railties/CHANGELOG.md) for previous changes.
