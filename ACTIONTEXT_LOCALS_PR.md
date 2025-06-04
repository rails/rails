# Add support for passing custom locals to ActionText attachment partials

## Summary

Add support for passing custom locals to ActionText attachment partials during content rendering.

This PR enables developers to pass additional context data to ActionText attachment partials, addressing a common need for customizing attachment rendering based on application-specific data like current user, theme, or permissions.

## Changes

### Core Implementation

- **ActionText::ContentHelper**: Enhanced `render_action_text_content` to accept optional `locals` parameter
- **ActionText::ContentHelper**: Updated `render_action_text_attachments` to merge custom locals with built-in `in_gallery` local
- **ActionText::Content**: Modified `to_s` and `to_rendered_html_with_layout` methods to accept and pass through locals
- **Content partial template**: Updated to pass locals from `local_assigns` to the helper

### API Changes

#### Before
```ruby
render_action_text_content(content)
content.to_s
```

#### After (backwards compatible)
```ruby
render_action_text_content(content, locals: { user: current_user })
content.to_s(locals: { theme: "dark" })
```

### Usage Example

```erb
<!-- In views -->
<%= message.content.to_s(locals: { user: current_user, theme: "dark" }) %>

<!-- In custom _blob.html.erb partial -->
<figure class="attachment">
  <% if local_assigns[:user] %>
    <span>Uploaded by: <%= local_assigns[:user].name %></span>
  <% end %>
  <% if local_assigns[:theme] == "dark" %>
    <span class="dark-theme">🌙</span>
  <% end %>
  <!-- existing attachment rendering -->
</figure>
```

## Testing

- Added comprehensive unit tests in `ActionText::ContentTest`
- Tests verify custom locals are properly merged with built-in locals
- Ensures backwards compatibility with existing code
- All existing ActionText tests continue to pass

## Backwards Compatibility

✅ **Fully backwards compatible** - all existing code continues to work without changes. The `locals` parameter is optional and defaults to an empty hash.

## Documentation

The new functionality is self-documenting through method signatures and follows existing Rails patterns for passing locals to partials.

## Motivation and Context

This addresses a long-standing limitation where developers couldn't pass custom data to ActionText attachment partials. Common use cases include:

- User context (showing uploader information)
- Theming (conditional styling based on theme)
- Permissions (showing/hiding content based on user roles)
- Localization (passing locale-specific data)

## Files Changed

```
actiontext/app/helpers/action_text/content_helper.rb
actiontext/app/views/action_text/contents/_content.html.erb
actiontext/lib/action_text/content.rb
actiontext/test/unit/content_test.rb
```

## Related Issues

Fixes #[issue_number] - Add support for passing locals to ActionText attachment partials

---

### Checklist

- [x] Tests added for new functionality
- [x] Backwards compatibility maintained
- [x] All existing tests pass
- [x] Code follows Rails conventions
- [x] No breaking changes introduced