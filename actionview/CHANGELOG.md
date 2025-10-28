## Rails 7.2.3 (October 28, 2025) ##

*   Fix `javascript_include_tag` `type` option to accept either strings and symbols.

    ```ruby
    javascript_include_tag "application", type: :module
    javascript_include_tag "application", type: "module"
    ```

    Previously, only the string value was recoginized.

    *Jean Boussier*

*   Fix `excerpt` helper with non-whitespace separator.

    *Jonathan Hefner*

*   Respect `html_options[:form]` when `collection_checkboxes` generates the
    hidden `<input>`.

    *Riccardo Odone*

*   Layouts have access to local variables passed to `render`.

    This fixes #31680 which was a regression in Rails 5.1.

    *Mike Dalessio*

*   Argument errors related to strict locals in templates now raise an
    `ActionView::StrictLocalsError`, and all other argument errors are reraised as-is.

    Previously, any `ArgumentError` raised during template rendering was swallowed during strict
    local error handling, so that an `ArgumentError` unrelated to strict locals (e.g., a helper
    method invoked with incorrect arguments) would be replaced by a similar `ArgumentError` with an
    unrelated backtrace, making it difficult to debug templates.

    Now, any `ArgumentError` unrelated to strict locals is reraised, preserving the original
    backtrace for developers.

    Also note that `ActionView::StrictLocalsError` is a subclass of `ArgumentError`, so any existing
    code that rescues `ArgumentError` will continue to work.

    Fixes #52227.

    *Mike Dalessio*

*   Fix stack overflow error in dependency tracker when dealing with circular dependencies

    *Jean Boussier*

*   Fix a crash in ERB template error highlighting when the error occurs on a
    line in the compiled template that is past the end of the source template.

    *Martin Emde*

*   Improve reliability of ERB template error highlighting.
    Fix infinite loops and crashes in highlighting and
    improve tolerance for alternate ERB handlers.

    *Martin Emde*


## Rails 7.2.2.2 (August 13, 2025) ##

*   No changes.


## Rails 7.2.2.1 (December 10, 2024) ##

*   No changes.


## Rails 7.2.2 (October 30, 2024) ##

*   No changes.


## Rails 7.2.1.2 (October 23, 2024) ##

*   No changes.


## Rails 7.2.1.1 (October 15, 2024) ##

*   No changes.


## Rails 7.2.1 (August 22, 2024) ##

*   No changes.


## Rails 7.2.0 (August 09, 2024) ##

*   Fix templates with strict locals to also include `local_assigns`.

    Previously templates defining strict locals wouldn't receive the `local_assigns`
    hash.

    *Jean Boussier*

*   Add queries count to template rendering instrumentation.

    ```
    # Before
    Completed 200 OK in 3804ms (Views: 41.0ms | ActiveRecord: 33.5ms | Allocations: 112788)

    # After
    Completed 200 OK in 3804ms (Views: 41.0ms | ActiveRecord: 33.5ms (2 queries, 1 cached) | Allocations: 112788)
    ```

    *fatkodima*

*   Raise `ArgumentError` if `:renderable` object does not respond to `#render_in`.

    *Sean Doyle*

*   Add the `nonce: true` option for `stylesheet_link_tag` helper to support automatic nonce generation for Content Security Policy.

    Works the same way as `javascript_include_tag nonce: true` does.

    *Akhil G Krishnan*, *AJ Esler*

*   Parse `ActionView::TestCase#rendered` HTML content as `Nokogiri::XML::DocumentFragment` instead of `Nokogiri::XML::Document`.

    *Sean Doyle*

*   Rename `ActionView::TestCase::Behavior::Content` to `ActionView::TestCase::Behavior::RenderedViewContent`.

    Make `RenderedViewContent` inherit from `String`. Make private API with `:nodoc:`

    *Sean Doyle*

*   Deprecate passing `nil` as value for the `model:` argument to the `form_with` method.

    *Collin Jilbert*

*   Alias `field_set_tag` helper to `fieldset_tag` to match `<fieldset>` element.

    *Sean Doyle*

*   Deprecate passing content to void elements when using `tag.br` type tag builders.

    *Hartley McGuire*

*   Fix the `number_to_human_size` view helper to correctly work with negative numbers.

    *Earlopain*

*   Automatically discard the implicit locals injected by collection rendering for template that can't accept them.

    When rendering a collection, two implicit variables are injected, which breaks templates with strict locals.

    Now they are only passed if the template will actually accept them.

    *Yasha Krasnou*, *Jean Boussier*

*   Fix `@rails/ujs` calling `start()` an extra time when using bundlers.

    *Hartley McGuire*, *Ryunosuke Sato*

*   Fix the `capture` view helper compatibility with HAML and Slim.

    When a blank string was captured in HAML or Slim (and possibly other template engines)
    it would instead return the entire buffer.

    *Jean Boussier*

*   Updated `@rails/ujs` files to ignore certain data-* attributes when element is contenteditable.

    This fix was already landed in >= 7.0.4.3, < 7.1.0.
    [[CVE-2023-23913](https://github.com/advisories/GHSA-xp5h-f8jf-rc8q)]

    *Ryunosuke Sato*

*   Added validation for HTML tag names in the `tag` and `content_tag` helper method.

    The `tag` and `content_tag` method now checks that the provided tag name adheres to the HTML
    specification. If an invalid HTML tag name is provided, the method raises an `ArgumentError`
    with an appropriate error message.

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
