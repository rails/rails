*   New syntax for tag helpers. Avoid positional parameters and support HTML5 by default.
    Example usage of tag helpers before:

    ```ruby
    tag(:br, nil, true)
    content_tag(:div, content_tag(:p, "Hello world!"), class: "strong")

    <%= content_tag :div, class: "strong" do -%>
      Hello world!
    <% end -%>
    ```

    Example usage of tag helpers after:

    ```ruby
    tag.br
    tag.div tag.p("Hello world!"), class: "strong"

    <%= tag.div class: "strong" do %>
      Hello world!
    <% end %>
    ```

    *Marek Kirejczyk*, *Kasper Timm Hansen*

*   Change `datetime_field` and `datetime_field_tag` to generate `datetime-local` fields.

    As a new specification of the HTML 5 the text field type `datetime` will no longer exist
    and it is recomended to use `datetime-local`.
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
     when the value as well as content for option tag are empty, so that we conform with html specification.
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
