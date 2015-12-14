module ActionCable
  module Helpers
    module ActionCableHelper
      # Returns an "action-cable-url" meta tag with the value of the url specified in your
      # configuration. Ensure this is above your javascript tag:
      #
      #   <head>
      #     <%= action_cable_meta_tag %>
      #     <%= javascript_include_tag 'application', 'data-turbolinks-track' => true %>
      #   </head>
      #
      # This is then used by ActionCable to determine the url of your websocket server.
      # Your CoffeeScript can then connect to the server without needing to specify the
      # url directly:
      #
      #   #= require cable
      #   @App = {}
      #   App.cable = Cable.createConsumer()
      #
      # Make sure to specify the correct server location in each of your environments
      # config file:
      #
      #   config.action_cable.url = "ws://example.com:28080"
      def action_cable_meta_tag
        tag "meta", name: "action-cable-url", content: Rails.application.config.action_cable.url
      end
    end
  end
end
