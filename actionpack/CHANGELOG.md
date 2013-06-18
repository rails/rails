*   Fix `Mime::Type.parse` when bad accepts header is looked up.

    *Becker* 
   
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

Please check [4-0-stable](https://github.com/rails/rails/blob/4-0-stable/actionpack/CHANGELOG.md) for previous changes.
