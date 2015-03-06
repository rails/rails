*   `number_to_percentage` does not crash with `Float::NAN` or `Float::INFINITY`
    as input when `precision: 0` is used.

    Fixes #19227.

    *Yves Senn*

*   Fixed the translation helper method to accept different default values types
    besides String.

    *Ulisses Almeida*

*   Collection rendering automatically caches and fetches multiple partials.

    Collections rendered as:

    ```ruby
    <%= render @notifications %>
    <%= render partial: 'notifications/notification', collection: @notifications, as: :notification %>
    ```

    will now read several partials from cache at once, if the template starts with a cache call:

    ```ruby
    # notifications/_notification.html.erb
    <% cache notification do %>
      <%# ... %>
    <% end %>
    ```

    *Kasper Timm Hansen*

*   Fixed a dependency tracker bug that caused template dependencies not
    count layouts as dependencies for partials.

    *Juho Leinonen*

*   Extracted `ActionView::Helpers::RecordTagHelper` to external gem
    (`record_tag_helper`) and added removal notices.

    *Todd Bealmear*

*   Allow to pass a string value to `size` option in `image_tag` and `video_tag`.

    This makes the behavior more consistent with `width` or `height` options.

    *Mehdi Lahmam*

*   Partial template name does no more have to be a valid Ruby identifier.

    There used to be a naming rule that the partial name should start with
    underscore, and should be followed by any combination of letters, numbers
    and underscores.
    But now we can give our partials any name starting with underscore, such as
    _🍔.html.erb.

    *Akira Matsuda*

*   Change the default template handler from `ERB` to `Raw`.

    Files without a template handler in their extension will be rendered using the raw
    handler instead of ERB.

    *Rafael Mendonça França*

*   Remove deprecated `AbstractController::Base::parent_prefixes`.

    *Rafael Mendonça França*

*   Default translations that have a lower precedence than a html safe default,
    but are not themselves safe, should not be marked as html_safe.

    *Justin Coyne*

*   Make possible to use blocks with short version of `render "partial"` helper.

    *Nikolay Shebanov*

*   Add a `hidden_field` on the `file_field` to avoid raise a error when the only
    input on the form is the `file_field`.

    *Mauro George*

*   Add an explicit error message, in `ActionView::PartialRenderer` for partial
    `rendering`, when the value of option `as` has invalid characters.

    *Angelo Capilleri*

*   Allow entries without a link tag in AtomFeedHelper.

    *Daniel Gomez de Souza*

Please check [4-2-stable](https://github.com/rails/rails/blob/4-2-stable/actionview/CHANGELOG.md) for previous changes.
