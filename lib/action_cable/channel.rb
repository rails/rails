module ActionCable
  module Channel
    autoload :Base, 'action_cable/channel/base'
    autoload :Callbacks, 'action_cable/channel/callbacks'
    autoload :PeriodicTimers, 'action_cable/channel/periodic_timers'
    autoload :Streams, 'action_cable/channel/streams'
  end
end
