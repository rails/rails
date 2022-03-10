*   New app generator includes `Procfile.dev` and `bin/dev`.

    Based off of the files provided by `jsbundling-rails` and `cssbundling-rails`, a `bin/dev` binary which executes
    `foreman` against a `Procfile.dev` file is now part of the default Rails install. This provides a single point
    of entry for starting up a local environment (server, frontend bundling, background job processe, etc.).

    Use `--skip-bin-dev` to skip these files for new apps.

    *Tony Drake*

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
