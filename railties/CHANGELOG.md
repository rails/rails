*   Rails::Generators::Actions#gem_group: Prepend existing gem groups

    Prior to this commit, calls to `gem_group` would amend the `Gemfile`
    even if there was an existing [gem group][], resulting in duplication.

    This commit prepends existing gem groups with the added gem.

    [gem groups]: https://bundler.io/guides/groups.html

    *Steve Polito*

*   Conditionally print `$stdout` when invoking `run_generator`

    In an effort to improve the developer experience when debugging
    generator tests, we add the ability to conditionally print `$stdout`
    instead of capturing it.

    This allows for calls to `binding.irb` and `puts` work as expected.

    ```sh
    RAILS_LOG_TO_STDOUT=true ./bin/test test/generators/actions_test.rb
    ```

    *Steve Polito*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/railties/CHANGELOG.md) for previous changes.
