*   `tag.attributes` returns `Hash`-like `ActionView::Attributes` instance

    When called outside of a rendering context, <tt>tag.attributes</tt>
    will return a <tt>Hash</tt>-like object that knows how to render
    itself to HTML:

        primary = { class: "bg-red-500 text-white" }
        large = { class: "text-lg p-4" }

        tag.attributes(primary, large).to_h
        # => { class: "bg-red-500 text-white text-lg p-4" }

        tag.attributes(primary, large).to_s
        # => "class=\"bg-red-500 text-white text-lg p-4\""

        button_tag "Click me!", tag.attributes(primary, large)
        # => <button name="button" type="submit" class="bg-red-500 text-white text-lg p-4">Click me!</button>

        tag.button "Click me!", id: "cta", **tag.attributes(primary, large)
        # => <button id="cta" class="bg-red-500 text-white text-lg p-4">Click me!</button>

    *Sean Doyle*

*   `tag.attributes` accepts a variable number of `Hash` arguments, then merges
    them from left to right:

    ```erb
    <input <%= tag.attributes({ id: "search" }, { type: :text }, { aria: { label: "Search" } }, aria: { disabled: true }) %> >
    <%# => <input id="search" type="text" aria-label="Search" aria-disabled="true"> %>
    ```

    *Sean Doyle*

*   Added validation for HTML tag names in the `tag` and `content_tag` helper method. The `tag` and
    `content_tag` method now checks that the provided tag name adheres to the HTML specification. If
    an invalid HTML tag name is provided, the method raises an `ArgumentError` with an appropriate error
    message.

    Examples:

    ```ruby
    # Raises ArgumentError: Invalid HTML5 tag name: 12p
    content_tag("12p") # Starting with a number

    # Raises ArgumentError: Invalid HTML5 tag name: ""
    content_tag("") # Empty tag name

    # Raises ArgumentError: Invalid HTML5 tag name: div/
    tag("div/") # Contains a solidus

    # Raises ArgumentError: Invalid HTML5 tag name: "image file"
    tag("image file") # Contains a space
    ```

    *Akhil G Krishnan*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/actionview/CHANGELOG.md) for previous changes.
