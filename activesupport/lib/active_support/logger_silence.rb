require 'active_support/concern'
require 'thread_safe'

module LoggerSilence
  extend ActiveSupport::Concern

  included do
    cattr_accessor :silencer
    self.silencer = true
  end

  # Silences the logger for the duration of the block.
  def silence(temporary_level = Logger::ERROR)
    if silencer
      begin
        old_local_level            = local_level
        self.local_level           = temporary_level

        yield self
      ensure
        self.local_level = old_local_level
      end
    else
      yield self
    end
  end
end
