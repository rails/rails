# ActionText Attachment Locals Usage Examples

This document demonstrates how to use the new `attachment_locals` feature in ActionText.

## Basic Usage

### In Controllers

```ruby
class MessagesController < ApplicationController
  def show
    @message = Message.find(params[:id])
    @current_user = current_user
  end
end
```

### In Views

```erb
<!-- Pass locals to attachment partials -->
<%= render @message.content, current_user: @current_user, can_edit: can?(:edit, @message) %>
```

### Custom Blob Partial

Create `app/views/active_storage/blobs/_blob.html.erb`:

```erb
<figure class="attachment attachment--<%= blob.representable? ? "preview" : "file" %> attachment--<%= blob.filename.extension %>">
  <% if blob.representable? %>
    <%= image_tag blob.representation(resize_to_limit: local_assigns[:in_gallery] ? [ 800, 600 ] : [ 1024, 768 ]) %>
  <% end %>

  <figcaption class="attachment__caption">
    <% if caption = blob.try(:caption) %>
      <%= caption %>
    <% else %>
      <span class="attachment__name"><%= blob.filename %></span>
      <span class="attachment__size"><%= number_to_human_size blob.byte_size %></span>
    <% end %>
    
    <!-- New: Access custom locals -->
    <% if local_assigns[:current_user] && local_assigns[:can_edit] %>
      <div class="attachment__actions">
        <%= link_to "Edit", edit_blob_path(blob), class: "btn btn-sm" %>
        <%= link_to "Delete", blob_path(blob), method: :delete, class: "btn btn-sm btn-danger" %>
      </div>
    <% end %>
  </figcaption>
</figure>
```

## Advanced Usage

### Using Helper Methods

```ruby
# In a helper
def render_rich_content_with_user_context(content, user)
  render_action_text_content(content, attachment_locals: { 
    current_user: user,
    can_edit: can?(:edit, content.record),
    user_preferences: user.preferences
  })
end
```

### Custom Attachable Partial

For custom attachables, you can also access the locals:

```erb
<!-- app/views/people/_person.html.erb -->
<div class="mentioned-person" data-person-id="<%= person.id %>">
  <strong><%= person.name %></strong>
  
  <% if local_assigns[:current_user] == person %>
    <span class="badge">You</span>
  <% elsif local_assigns[:current_user]&.follows?(person) %>
    <span class="badge">Following</span>
  <% end %>
</div>
```

## Backwards Compatibility

The new feature is fully backwards compatible. Existing code will continue to work:

```erb
<!-- This still works -->
<%= @message.content %>

<!-- This also still works -->
<%= render_action_text_content(@message.content) %>
``` 
