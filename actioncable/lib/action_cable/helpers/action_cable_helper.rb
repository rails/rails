module ActionCable
  module Helpers
    module ActionCableHelper
      # Returns an "action-cable-url" meta tag with the value of the URL specified in your
      # configuration. Ensure this is above your JavaScript tag:
      #
      #   <head>
      #     <%= action_cable_meta_tag %>
      #     <%= javascript_include_tag 'application', 'data-turbolinks-track' => 'reload' %>
      #   </head>
      #
      # This is then used by Action Cable to determine the URL of your WebSocket server.
      # Your CoffeeScript can then connect to the server without needing to specify the
      # URL directly:
      #
      #   #= require cable
      #   @App = {}
      #   App.cable = Cable.createConsumer()
      #
      # Make sure to specify the correct server location in each of your environment
      # config files:
      #
      #   config.action_cable.mount_path = "/cable123"
      #   <%= action_cable_meta_tag %> would render:
      #   => <meta name="action-cable-url" content="/cable123" />
      #
      #   config.action_cable.url = "ws://actioncable.com"
      #   <%= action_cable_meta_tag %> would render:
      #   => <meta name="action-cable-url" content="ws://actioncable.com" />
      #
      def action_cable_meta_tag
        tag "meta", name: "action-cable-url", content: (
          ActionCable.server.config.url ||
          ActionCable.server.config.mount_path ||
          raise("No Action Cable URL configured -- please configure this at config.action_cable.url")
        )
      end
    end
  end
end
