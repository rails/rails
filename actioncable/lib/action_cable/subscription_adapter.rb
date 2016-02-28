# frozen_string_literal: true
module ActionCable
  module SubscriptionAdapter
    extend ActiveSupport::Autoload

    autoload :Base
    autoload :SubscriberMap
  end
end
