module ActionCable
  module Channel
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :Base
      autoload :Broadcasting
      autoload :Callbacks
      autoload :Naming
      autoload :PeriodicTimers
      autoload :Streams
      autoload :TestCase
    end
  end
end
