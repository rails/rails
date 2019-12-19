# frozen_string_literal: true

module ActionCable
  module SubscriptionAdapter
    extend ActiveSupport::Autoload

    autoload :Base
    autoload :Test
    autoload :SubscriberMap
    autoload :ChannelPrefix
  end
end
