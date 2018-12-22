*   Add `rails credentials:encrypt` command to support create credentials
    from a cleartext YAML file.

    It reads `config/credentials.yml` by default, if `--environment` given
    it will reads `config/credentials/:environment.yml`.

    You can specify other YAML file by using `--file`,
    e.g: `rails credentials:encrypt --file config/secret.yml`.

    If `credentials.yml.enc` already exists, you have to give `--force` to
    replace it.

    If `master.key` doesn't exist, it will generate one.

    The cleartext YAML file will be deleted unless you give `--keep-cleartext`

    *Jiang Jun*

*   Add benchmark method that can be called from anywhere.

    This method is used as a quick way to measure & log the speed of some code.
    However, it was previously available only in specific contexts, mainly views and controllers.
    The new Rails.benchmark can be used in the rest of your app: services, API wrappers, models, etc.

        def test
          Rails.benchmark("test") { ... }
        end

    *Simon Perepelitsa*

*   Only execute route reloads once on boot for development environment

## Rails 6.1.0.rc1 (November 02, 2020) ##

    *Louis Cloutier*
>>>>>>> beec2a3e26... add `rails credentials:encrypt` that helps for encrypt a cleartext YAML as credentials

*   Removed manifest.js and application.css in app/assets
    folder when --skip-sprockets option passed as flag to rails.

    *Cindy Gao*

*   Add support for stylesheets and ERB views to `rails stats`.

    *Joel Hawksley*

*   Allow appended root routes to take precedence over internal welcome controller.

    *Gannon McGibbon*


Please check [6-1-stable](https://github.com/rails/rails/blob/6-1-stable/railties/CHANGELOG.md) for previous changes.
