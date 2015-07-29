module ActionCable
  module Channel
    autoload :Base, 'action_cable/channel/base'
    autoload :Broadcasting, 'action_cable/channel/broadcasting'
    autoload :Callbacks, 'action_cable/channel/callbacks'
    autoload :Naming, 'action_cable/channel/naming'
    autoload :PeriodicTimers, 'action_cable/channel/periodic_timers'
    autoload :Streams, 'action_cable/channel/streams'
  end
end
