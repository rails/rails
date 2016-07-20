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

*   Default `config.assets.quiet = true` in the development environment. Suppress
    logging of assets requests by default.

    *Kevin McPhillips*

*   Ensure `/rails/info` routes match in development for apps with a catch-all globbing route.

    *Nicholas Firth-McCoy*

*   Added a shared section to `config/secrets.yml` that will be loaded for all environments.

    *DHH*

Please check [5-0-stable](https://github.com/rails/rails/blob/5-0-stable/railties/CHANGELOG.md) for previous changes.
