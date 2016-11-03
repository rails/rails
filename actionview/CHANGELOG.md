*   Removed deprecated `#original_exception` in `ActionView::Template::Error`.

    *Rafael Mendonça França*

*   Render now accepts any keys for locals, including reserved words

    Only locals with valid variable names get set directly. Others
    will still be available in local_assigns.

    Example of render with reserved words:

    ```erb
    <%= render "example", class: "text-center", message: "Hello world!" %>

    <!-- _example.html.erb: -->
    <%= tag.div class: local_assigns[:class] do %>
      <p><%= message %></p>
    <% end %>
    ```

    *Peter Schilling*, *Matthew Draper*

*   Show cache hits and misses when rendering partials.

    Partials using the `cache` helper will show whether a render hit or missed
    the cache:

    ```
    Rendered messages/_message.html.erb in 1.2 ms [cache hit]
    Rendered recordings/threads/_thread.html.erb in 1.5 ms [cache miss]
    ```

    This removes the need for the old fragment cache logging:

    ```
    Read fragment views/v1/2914079/v1/2914079/recordings/70182313-20160225015037000000/d0bdf2974e1ef6d31685c3b392ad0b74 (0.6ms)
    Rendered messages/_message.html.erb in 1.2 ms [cache hit]
    Write fragment views/v1/2914079/v1/2914079/recordings/70182313-20160225015037000000/3b4e249ac9d168c617e32e84b99218b5 (1.1ms)
    Rendered recordings/threads/_thread.html.erb in 1.5 ms [cache miss]
    ```

    Though that full output can be reenabled with
    `config.action_controller.enable_fragment_cache_logging = true`.

    *Stan Lo*

*   Changed partial rendering with a collection to allow collections which
    implement `to_a`.

    Extracting the collection option had an optimization to avoid unnecessary
    queries of ActiveRecord Relations by calling `#to_ary` on the given
    collection. Instances of `Enumerator` or `Enumerable` are valid
    collections, but they do not implement `#to_ary`. By changing this to
    `#to_a`, they will now be extracted and rendered as expected.

    *Steven Harman*

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
    and it is recommended to use `datetime-local`.
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
