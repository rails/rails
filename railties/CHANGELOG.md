*   `rails/test_help`: Define `aria:` and `data:` Capybara expression filters

    When `Capybara` is available to the environment, define `aria:` and `data:`
    expression filters to match Action View's `aria: { ... }` and `data: { ... }`
    nesting:

    ```ruby
    tag.div id: "one", aria: { labelledby: "two" }, data: { nested_key: "value" }
    # => <div id="one" aria-labelledby="two" data-nested-key="value"></div>

    assert_selector :element, aria: { labelledby: "two" }, data: { nested_key: "value" }
    ```

    *Sean Doyle*

*   Disallow invalid values for rails new options.

    The `--database`, `--asset-pipeline`, `--css`, and `--javascript` flags for
    `rails new` can all take different options. This change adds checks to
    options to make sure the user enters the correct value.

    *Tony Drake*, *Akhil G Krishnan*, *Petrik de Heus*

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
