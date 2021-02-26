*   Allow adding additional authorized hosts in development via `ENV['RAILS_DEVELOPMENT_HOSTS']`

    *Josh Abernathy*, *Debbie Milburn*

*   Stop generating a license for in-app plugins.

    *Gannon McGibbon*

*   `rails app:update` no longer prompts you to overwrite files that are generally modified in the
    course of developing a Rails app. See [#41083](https://github.com/rails/rails/pull/41083) for
    the full list of changes.

    *Alex Ghiculescu*

*   Change default branch for new Rails projects and plugins to `main`.

    *Prateek Choudhary*

*   Add benchmark method that can be called from anywhere.

    This method is used as a quick way to measure & log the speed of some code.
    However, it was previously available only in specific contexts, mainly views and controllers.
    The new Rails.benchmark can be used in the rest of your app: services, API wrappers, models, etc.

        def test
          Rails.benchmark("test") { ... }
        end

    *Simon Perepelitsa*

*   Removed manifest.js and application.css in app/assets
    folder when --skip-sprockets option passed as flag to rails.

    *Cindy Gao*

*   Add support for stylesheets and ERB views to `rails stats`.

    *Joel Hawksley*

*   Allow appended root routes to take precedence over internal welcome controller.

    *Gannon McGibbon*


Please check [6-1-stable](https://github.com/rails/rails/blob/6-1-stable/railties/CHANGELOG.md) for previous changes.
