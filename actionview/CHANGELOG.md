*   Remove the deprecated `prompt` argument from `grouped_options_for_select`,
    pass in a `:prompt` hash option to use this feature.

    *kennyj*

*   Always escape the result of `link_to_unless` method.

    Before:

        link_to_unless(true, '<b>Showing</b>', 'github.com')
        # => "<b>Showing</b>"

    After:

        link_to_unless(true, '<b>Showing</b>', 'github.com')
        # => "&lt;b&gt;Showing&lt;/b&gt;"

    *dtaniwaki*

*   Use a case insensitive URI Regexp for #asset_path.

    This fix a problem where the same asset path using different case are generating
    different URIs.

    Before:

        image_tag("HTTP://google.com")
        # => "<img alt=\"Google\" src=\"/assets/HTTP://google.com\" />"
        image_tag("http://google.com")
        # => "<img alt=\"Google\" src=\"http://google.com\" />"

    After:

        image_tag("HTTP://google.com")
        # => "<img alt=\"Google\" src=\"HTTP://google.com\" />"
        image_tag("http://google.com")
        # => "<img alt=\"Google\" src=\"http://google.com\" />"

    *David Celis*

*   Element of the `collection_check_boxes` and `collection_radio_buttons` can
    optionally contain html attributes as the last element of the array.

    *Vasiliy Ermolovich*

*   Update the HTML `BOOLEAN_ATTRIBUTES` in `ActionView::Helpers::TagHelper`
    to conform to the latest HTML 5.1 spec. Add attributes `allowfullscreen`,
    `default`, `inert`, `sortable`, `truespeed`, `typemustmatch`. Fix attribute
    `seamless` (previously misspelled `seemless`).

    *Alex Peattie*

*   Fix an issue where partials with a number in the filename weren't being digested for cache dependencies.

    *Bryan Ricker*

*   First release, ActionView extracted from ActionPack

    *Piotr Sarnacki*, *Łukasz Strzałkowski*

Please check [4-0-stable (ActionPack's CHANGELOG)](https://github.com/rails/rails/blob/4-0-stable/actionpack/CHANGELOG.md) for previous changes.
