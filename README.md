# Active Text

🤸‍♂️💰📝

## Installing

Assumes a Rails 5.2+ application with Active Storage and Webpacker installed.

1. Install the gem:

    ```ruby
    # Gemfile
    gem "activetext", github: "basecamp/activetext", require: "active_text"
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

1. Declare text columns as Active Text attributes:

    ```ruby
    # app/models/message.rb
    class Message < ActiveRecord::Base
      active_text_attribute :content
    end
    ```

1. Replace form `text_area`s with `active_text_field`s:

    ```erb
    <%# app/views/messages/_form.html.erb %>
    <%= form_with(model: message) do |form| %>
      …
      <div class="field">
        <%= form.label :content %>
        <%= form.active_text_field :content %>
      </div>
      …
    <% end %>
    ```
