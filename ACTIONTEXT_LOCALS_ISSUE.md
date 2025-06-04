# Add support for passing locals to ActionText attachment partials

## Summary

Currently, there is no way to pass custom locals to ActionText attachment partials when rendering content. When a user creates a custom partial (e.g., `_blob.html.erb`) for ActionText attachments, they cannot access any custom data beyond the attachment object itself and the built-in `in_gallery` local.

## Problem

When rendering ActionText content like `<%= object.content %>`, developers cannot pass additional context or data to the attachment partials. This limits the ability to customize attachment rendering based on the current user, theme, or other application-specific data.

### Current Behavior

```erb
<!-- No way to pass custom data to attachment partials -->
<%= message.content %>
```

```erb
<!-- In _blob.html.erb - only built-in locals available -->
<figure class="attachment">
  <!-- Can only access: blob, in_gallery -->
  <!-- Cannot access: current_user, theme, etc. -->
</figure>
```

### Expected Behavior

```erb
<!-- Should be able to pass custom locals -->
<%= message.content.to_s(locals: { user: current_user, theme: "dark" }) %>
```

```erb
<!-- In _blob.html.erb - custom locals should be available -->
<figure class="attachment">
  <% if local_assigns[:user] %>
    <span>Uploaded by: <%= local_assigns[:user].name %></span>
  <% end %>
  <% if local_assigns[:theme] == "dark" %>
    <span class="dark-mode">🌙</span>
  <% end %>
</figure>
```

## Use Cases

1. **User context**: Show who uploaded an attachment
2. **Theming**: Render attachments differently based on current theme
3. **Permissions**: Show/hide attachment details based on user permissions
4. **Localization**: Pass locale-specific data to attachment partials
5. **Feature flags**: Conditionally render attachment features

## Proposed Solution

Enhance the ActionText rendering pipeline to accept and pass through custom locals:

1. Modify `ActionText::ContentHelper#render_action_text_content` to accept a `locals` parameter
2. Update `ActionText::Content#to_s` and related methods to accept locals
3. Ensure custom locals are merged with existing built-in locals (`in_gallery`)
4. Maintain full backwards compatibility

## Rails Version

Rails 8.1.0 (main branch)