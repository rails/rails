# frozen_string_literal: true

# :markup: markdown

module ActionCable
  module Helpers
    module ActionCableHelper
      # Returns an "action-cable-url" meta tag with the value of the URL specified in
      # your configuration. Ensure this is above your JavaScript tag:
      #
      #     <head>
      #       <%= action_cable_meta_tag %>
      #       <%= javascript_include_tag 'application', 'data-turbo-track' => 'reload' %>
      #     </head>
      #
      # This is then used by Action Cable to determine the URL of your WebSocket
      # server. Your JavaScript can then connect to the server without needing to
      # specify the URL directly:
      #
      #     import Cable from "@rails/actioncable"
      #     window.Cable = Cable
      #     window.App = {}
      #     App.cable = Cable.createConsumer()
      #
      # Make sure to specify the correct server location in each of your environment
      # config files:
      #
      #     config.action_cable.mount_path = "/cable123"
      #     <%= action_cable_meta_tag %> would render:
      #     => <meta name="action-cable-url" content="/cable123" />
      #
      #     config.action_cable.url = "ws://actioncable.com"
      #     <%= action_cable_meta_tag %> would render:
      #     => <meta name="action-cable-url" content="ws://actioncable.com" />
      #
      def action_cable_meta_tag
        tag "meta", name: "action-cable-url", content: (
          ActionCable.server.config.url ||
          ActionCable.server.config.mount_path ||
          raise("No Action Cable URL configured -- please configure this at config.action_cable.url")
        )
      end

      # Returns a list of channels that match the broadcast_to_list nomenclature
      # For example, if channel is "posts:1", and channels is ["posts:1-2", "posts:2-3", "posts:1-3"],
      # this method will return ["posts:1-2", "post:1-3"].
      # channel attr must have parts separated by ":" and must have at least 2 parts
      # channels must have parts separated by ":" and must have at least 2 parts, and in the last part
      # which represents the identifiers, they must be separated by "-"
      def find_matching_channels(channel, channels)
        parts = channel.split(":")
        return [] if parts.length == 1

        id = parts.pop
        base_channel = parts.join(":")

        channels.filter_map do |ch|
          if ch.start_with?(base_channel)
            ids = ch.split(":").last
            ch if ids != ch && ids.split("-").include?(id)
          end
        end
      end
    end
  end
end
