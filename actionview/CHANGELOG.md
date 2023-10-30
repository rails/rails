*   Rename `ActionView::TestCase::Behavior::{Content,RenderedViewContent}`

    *Sean Doyle*

*   Raise `ArgumentError` when `nil` is passed as `model:` argument value to the `form_with` method.

    *Collin Jilbert*

*   Alias `field_set_tag` helper to `fieldset_tag` to match `<fieldset>` element

    *Sean Doyle*

*   Deprecate passing content to void elements when using `tag.br` type tag builders.

    *Hartley McGuire*

*   Fix the `number_to_human_size` view helper to correctly work with negative numbers.

    *Earlopain*

*   Automatically discard the implicit locals injected by collection rendering for template that can't accept them

    When rendering a collection, two implicit variables are injected, which breaks templates with strict locals.

    Now they are only passed if the template will actually accept them.

    *Yasha Krasnou*, *Jean Boussier*

*   Fix `@rails/ujs` calling `start()` an extra time when using bundlers

    *Hartley McGuire*, *Ryunosuke Sato*

*   Fix the `capture` view helper compatibility with HAML and Slim

    When a blank string was captured in HAML or Slim (and possibly other template engines)
    it would instead return the entire buffer.

    *Jean Boussier*

*   Updated `@rails/ujs` files to ignore certain data-* attributes when element is contenteditable.

    This fix was already landed in >= 7.0.4.3, < 7.1.0.
    [[CVE-2023-23913](https://github.com/advisories/GHSA-xp5h-f8jf-rc8q)]

    *Ryunosuke Sato*

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
