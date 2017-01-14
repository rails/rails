module ActionCable
  module Connection
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :Authorization
      autoload :Base
      autoload :Identification
      autoload :InternalChannel
      autoload :Streams
      autoload :Subscriptions
    end
  end
end
