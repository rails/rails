*   Extend `dom_id` and `dom_class` to accept a variable set of prefixes:

    ```ruby
    dom_class @post, :first_prefix, :second_prefix
    # => "first_prefix_second_prefix_post"
    dom_class @post, [:first_prefix, :second_prefix]
    # => "first_prefix_second_prefix_post"
    dom_id @post, :first_prefix, :second_prefix
    # => "first_prefix_second_prefix_post_123"
    dom_id @post, [:first_prefix, :second_prefix]
    # => "first_prefix_second_prefix_post_123"
    ```

    *Sean Doyle*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/actionview/CHANGELOG.md) for previous changes.
