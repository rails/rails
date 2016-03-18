module ActionCable
  module Server
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :Base
      autoload :Broadcasting
      autoload :Connections
      autoload :Configuration

      autoload :Worker
      autoload :ActiveRecordConnectionManagement, 'action_cable/server/worker/active_record_connection_management'
    end
  end
end
