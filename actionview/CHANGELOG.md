*   A change was made in the helper that renders the `datetime`, being now by default `datetime-local` and
    creating an alias of `datetime-local` for `datetime`, `datetime` tag and it passes to be an abstract class for all other tags that inherit from him.

    As a new specification of the HTML 5 the text field type `datetime` will no longer exist and will pass a `datetime-local`.
    Ref: https://html.spec.whatwg.org/multipage/forms.html#local-date-and-time-state-(type=datetime-local)

    *Herminio Torres*

*   Raw template handler (which is also the default template handler in Rails 5) now outputs
    HTML-safe strings.

    In Rails 5 the default template handler was changed to the raw template handler. Because
    the ERB template handler escaped strings by default this broke some applications that
    expected plain JS or HTML files to be rendered unescaped. This fixes the issue caused
    by changing the default handler by changing the Raw template handler to output HTML-safe
    strings.

    *Eileen M. Uchitelle*

*   `select_tag`'s `include_blank` option for generation for blank option tag, now adds an empty space label,
     when the value as well as content for option tag are empty, so that we confirm with html specification.
     Ref: https://www.w3.org/TR/html5/forms.html#the-option-element.

    Generation of option before:

    ```html
    <option value=""></option>
    ```

    Generation of option after:

    ```html
    <option value="" label=" "></option>
    ```

    *Vipul A M*

Please check [5-0-stable](https://github.com/rails/rails/blob/5-0-stable/actionview/CHANGELOG.md) for previous changes.
