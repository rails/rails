module ActionCable
  module Connection
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :Base
      autoload :ClientSocket
      autoload :MessageBuffer
      autoload :Stream
      autoload :StreamEventLoop
      autoload :TaggedLoggerProxy
      autoload :WebSocket
    end
  end
end
