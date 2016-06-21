*   New syntax for tag helpers. Avoid positional parameters and support HTML5 by default.
    Example usage of tag helpers before:

    ```ruby
    tag(:br)
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

    *Marek Kirejczyk*

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
