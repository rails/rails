module ActionCable
  module Connection
    autoload :Base, 'action_cable/connection/base'
    autoload :Identification, 'action_cable/connection/identification'
    autoload :InternalChannel, 'action_cable/connection/internal_channel'
    autoload :TaggedLoggerProxy, 'action_cable/connection/tagged_logger_proxy'
  end
end
