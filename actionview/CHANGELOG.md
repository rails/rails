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
