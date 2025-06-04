*   The Trix dependency is now satisfied by a gem, `action_text-trix`, rather than vendored
    files. This allows applications to bump Trix versions independently of Rails
    releases. Effectively this also upgrades Trix to `>= 2.1.15`.

    *Mike Dalessio*

*   Change `ActionText::RichText#embeds` assignment from `before_save` to `before_validation`

    *Sean Doyle*

*   Add support for passing locals to ActionText attachment partials.

    The `render_action_text_content` helper method now accepts an `attachment_locals` keyword argument
    that allows passing custom local variables to attachment partials.

    ```ruby
    # In views
    <%= render_action_text_content(@message.content, attachment_locals: { current_user: current_user }) %>

    # In custom attachment partials
    <% if local_assigns[:current_user] %>
      <span>Uploaded by: <%= local_assigns[:current_user].name %></span>
    <% end %>
    ```

    This change maintains full backwards compatibility.

    *Piotr Witek*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/actiontext/CHANGELOG.md) for previous changes.
