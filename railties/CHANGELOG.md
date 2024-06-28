*   Deprecate `::STATS_DIRECTORIES`.

    The global constant `STATS_DIRECTORIES` has been deprecated in favor of
    `CodeStatistics.add_directory`.

    Add extra directories with `CodeStatistics.add_directory(label, path)` instead:
    ```ruby
    require "rails/code_statistics"
    CodeStatistics.add_directory('My Directory', 'path/to/dir')
    ```

    *Petrik de Heus*

*   Add internal page `/rails/info/notes`, that displays the same information as `bin/rails notes`.

    *Deepak Mahakale*

*   Add Rubocop and GitHub Actions to plugin generator.
    This can be skipped using --skip-rubocop and --skip-ci.

    *Chris Oliver*

*   Use Kamal for deployment by default, which includes generating a Rails-specific config/deploy.yml.
    This can be skipped using --skip-kamal. See more: https://kamal-deploy.org/

    *DHH*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/railties/CHANGELOG.md) for previous changes.
