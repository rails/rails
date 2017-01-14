module ActionCable
  module Socket
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :Base
      autoload :ClientSocket
      autoload :MessageBuffer
      autoload :Stream
      autoload :TaggedLoggerProxy
      autoload :WebSocket
    end
  end
end
