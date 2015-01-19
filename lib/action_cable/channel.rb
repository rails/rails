module ActionCable
  module Channel
    autoload :Callbacks, 'action_cable/channel/callbacks'
    autoload :Redis, 'action_cable/channel/redis'
    autoload :Base, 'action_cable/channel/base'
  end
end
