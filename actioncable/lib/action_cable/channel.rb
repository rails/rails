# frozen_string_literal: true

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
    end
  end
end
