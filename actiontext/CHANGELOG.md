*   Delegate `ActionText::Content#deconstruct` to `Nokogiri::XML::DocumentFragment#elements`

    ```ruby
    content = ActionText::Content.new <<~HTML
      <h1>Hello, world</h1>

      <div>The body</div>
    HTML

    content => [h1, div]

    assert_pattern { h1 => { content: "Hello, world" } }
    assert_pattern { div => { content: "The body" } }
    ```

    *Sean Doyle*

*   Fix all Action Text database related models to respect
    `ActiveRecord::Base.table_name_prefix` configuration.

    *Chedli Bourguiba*

*   Compile ESM package that can be used directly in the browser as actiontext.esm.js

    *Matias Grunberg*

*   Fix using actiontext.js with Sprockets

    *Matias Grunberg*

*   Upgrade Trix to 2.0.7

    *Hartley McGuire*

*   Fix using Trix with Sprockets

    *Hartley McGuire*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/actiontext/CHANGELOG.md) for previous changes.
