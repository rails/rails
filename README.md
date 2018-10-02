# Action Text

🤸‍♂️💰📝

## Installing

Assumes a Rails 5.2+ application with Active Storage and Webpacker installed.

1. Install the gem:

    ```ruby
    # Gemfile
    gem "actiontext", github: "basecamp/actiontext", require: "action_text"
    gem "image_processing", "~> 1.2" # for Active Storage variants
    ```
   
1. Install assets, npm dependency, and migrations

   ```
   ./bin/rails action_text:install
   ./bin/rails db:migrate
   ```

1. Declare text columns as Action Text attributes:

    ```ruby
    # app/models/message.rb
    class Message < ActiveRecord::Base
      has_rich_text :content
    end
    ```

1. Replace form `text_area`s with `rich_text_area`s:

    ```erb
    <%# app/views/messages/_form.html.erb %>
    <%= form_with(model: message) do |form| %>
      …
      <div class="field">
        <%= form.label :content %>
        <%= form.rich_text_area :content %>
      </div>
      …
    <% end %>
    ```
