*   Make Rails' test runner work better with minitest plugins.

    By demoting the Rails test runner to just another minitest plugin —
    and thereby not eager loading it — we can co-exist much better with
    other minitest plugins such as pride and minitest-focus.

    *Kasper Timm Hansen*

*   Load environment file in `dbconsole` command.

    Fixes #29717

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
