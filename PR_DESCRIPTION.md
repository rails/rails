# Add support for passing locals to ActionText attachment partials

## Summary

This PR adds the ability to pass custom local variables to ActionText attachment partials, enabling developers to customize attachment rendering based on view context (e.g., current user, permissions, etc.).

## Motivation

Currently, when rendering ActionText content with attachments (like ActiveStorage::Blobs), there's no way to pass additional context from the view to the attachment partials. This limits the ability to:

- Show user-specific actions (edit/delete buttons for file owners)
- Display contextual information based on current user
- Customize rendering based on view state or permissions

## Changes Made

### 1. Core Implementation

- **`ActionText::ContentHelper#render_action_text_content`**: Added `attachment_locals:` keyword argument
- **`ActionText::ContentHelper#render_action_text_attachments`**: Updated to pass locals through to attachments
- **`app/views/action_text/contents/_content.html.erb`**: Modified to forward locals to `render_action_text_content`

### 2. Backwards Compatibility

All changes are fully backwards compatible:
- Existing `<%= content %>` calls continue to work unchanged
- Existing `render_action_text_content(content)` calls continue to work unchanged
- New `attachment_locals:` parameter is optional with default empty hash

### 3. Testing

- Added comprehensive unit tests in `ActionText::ContentHelperTest`
- Tests cover normal attachments, gallery attachments, and backwards compatibility
- Added integration test to verify end-to-end functionality

### 4. Documentation

- Added changelog entry
- Created usage examples with practical scenarios
- Included test fixtures demonstrating the feature

## Usage Examples

### Basic Usage

```ruby
# In controllers
class MessagesController < ApplicationController
  def show
    @message = Message.find(params[:id])
  end
end
```

```erb
<!-- In views -->
<%= render @message.content, current_user: current_user, can_edit: can?(:edit, @message) %>
```

### Custom Blob Partial

```erb
<!-- app/views/active_storage/blobs/_blob.html.erb -->
<figure class="attachment">
  <%= image_tag blob.representation(resize_to_limit: [1024, 768]) if blob.representable? %>
  
  <figcaption>
    <span><%= blob.filename %></span>
    
    <!-- New: Access custom locals -->
    <% if local_assigns[:current_user] && local_assigns[:can_edit] %>
      <div class="attachment-actions">
        <%= link_to "Edit", edit_blob_path(blob) %>
        <%= link_to "Delete", blob_path(blob), method: :delete %>
      </div>
    <% end %>
  </figcaption>
</figure>
```

### Helper Methods

```ruby
def render_rich_content_with_context(content, user)
  render_action_text_content(content, attachment_locals: {
    current_user: user,
    can_edit: can?(:edit, content.record),
    user_preferences: user.preferences
  })
end
```

## Technical Details

### Implementation Strategy

1. **Minimal API Surface**: Added single `attachment_locals:` keyword argument
2. **Deep Integration**: Locals are passed through the entire attachment rendering pipeline
3. **Gallery Support**: Both individual attachments and gallery attachments receive locals
4. **Built-in Locals Preserved**: The existing `in_gallery` local is preserved and merged with custom locals

### Key Method Signatures

```ruby
# Before
render_action_text_content(content)

# After (backwards compatible)
render_action_text_content(content, attachment_locals: {})
```

### Files Modified

- `actiontext/app/helpers/action_text/content_helper.rb`
- `actiontext/app/views/action_text/contents/_content.html.erb`
- `actiontext/CHANGELOG.md`

### Files Added

- `actiontext/test/unit/content_helper_test.rb`
- `actiontext/examples/attachment_locals_usage.md`
- `actiontext/test/fixtures/views/active_storage/blobs/_blob_with_locals.html.erb`

## Testing

The implementation includes comprehensive tests covering:

- ✅ Basic content rendering without attachments
- ✅ Content rendering with blob attachments
- ✅ Custom locals being passed to attachment partials
- ✅ Gallery attachments receiving both custom locals and `in_gallery: true`
- ✅ Backwards compatibility with existing code
- ✅ Partial rendering through the content partial with locals

## Migration Path

This is a purely additive change. Existing applications will continue to work without modification. To use the new feature:

1. Update ActionText (this will be included in the next Rails release)
2. Modify your views to pass locals: `<%= render content, user: current_user %>`
3. Update your attachment partials to use `local_assigns[:user]`

## Related Issues

This addresses the common pain point mentioned in several Rails issues and discussions where developers needed to monkey-patch ActionText to pass context to attachment partials.

## Checklist

- [x] Implementation is backwards compatible
- [x] Tests added and passing
- [x] Documentation updated
- [x] Changelog entry added
- [x] Code follows Rails conventions
- [x] No performance regressions
- [x] Works with both individual attachments and galleries 
