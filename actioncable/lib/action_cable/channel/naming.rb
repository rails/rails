# frozen_string_literal: true

# :markup: markdown

module ActionCable
  module Channel
    module Naming
      extend ActiveSupport::Concern

      module ClassMethods
        # Returns the name of the channel, underscored, without the `Channel` ending. If
        # the channel is in a namespace, then the namespaces are represented by single
        # colon separators in the channel name.
        #
        #     ChatChannel.channel_name # => 'chat'
        #     Chats::AppearancesChannel.channel_name # => 'chats:appearances'
        #     FooChats::BarAppearancesChannel.channel_name # => 'foo_chats:bar_appearances'
        def channel_name
          @channel_name ||= name.delete_suffix("Channel").gsub("::", ":").underscore
        end
      end

      def channel_name
        self.class.channel_name
      end
    end
  end
end
