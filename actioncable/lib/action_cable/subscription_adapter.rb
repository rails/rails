module ActionCable
  module SubscriptionAdapter
    autoload :Base, 'action_cable/subscription_adapter/base'
    autoload :PostgreSQL, 'action_cable/subscription_adapter/postgresql'
    autoload :Redis, 'action_cable/subscription_adapter/redis'
  end
end
