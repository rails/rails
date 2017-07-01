module ActionCable
  module SubscriptionAdapter
    extend ActiveSupport::Autoload

    autoload :Base
    autoload :SubscriberMap
    autoload :ChannelPrefix
  end
end
