# Action Text

🤸‍♂️💰📝

## Installing

Assumes a Rails 5.2+ application with Active Storage and Webpacker installed.

1. Install the gem:

    ```ruby
    # Gemfile
    gem "activetext", github: "basecamp/activetext", require: "action_text"
    gem "mini_magick" # for Active Storage variants
    ```
   
1. Install the npm package:

    ```js
    // package.json
    "dependencies": {
      "activetext": "basecamp/activetext"
    }
    ```
    
    ```sh
    $ yarn install
    ```
    
    ```js
    // app/javascript/packs/application.js
    import "activetext"
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
