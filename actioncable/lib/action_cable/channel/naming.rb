# frozen_string_literal: true

module ActionCable
  module Channel
    module Naming
      extend ActiveSupport::Concern

      module ClassMethods
        # Returns the name of the channel, underscored, without the <tt>Channel</tt> ending.
        # If the channel is in a namespace, then the namespaces are represented by single
        # colon separators in the channel name.
        #
        #   ChatChannel.channel_name # => 'chat'
        #   Chats::AppearancesChannel.channel_name # => 'chats:appearances'
        #   FooChats::BarAppearancesChannel.channel_name # => 'foo_chats:bar_appearances'
        def channel_name
          @channel_name ||= name.sub(/Channel$/, "").gsub("::", ":").underscore
        end
      end

      # Delegates to the class' <tt>channel_name</tt>
      delegate :channel_name, to: :class
    end
  end
end
