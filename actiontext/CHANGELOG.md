*   Treat `Content#to_html` and `Content#to_trix_html` as safe

    ```ruby
    content = ActionText::Content.new("<div>hello world</div>")

    content.to_html.html_safe? # => true
    content.to_trix_html.html_safe? # => true
    ```

    *Sean Doyle*

*   Compile ESM package that can be used directly in the browser as actiontext.esm.js

    *Matias Grunberg*

*   Fix using actiontext.js with Sprockets

    *Matias Grunberg*

*   Upgrade Trix to 2.0.7

    *Hartley McGuire*

*   Fix using Trix with Sprockets

    *Hartley McGuire*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/actiontext/CHANGELOG.md) for previous changes.
