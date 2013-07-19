require 'active_support/concern'
require 'thread'

module LoggerSilence
  extend ActiveSupport::Concern

  included do
    cattr_accessor :silencer
    self.silencer = true
  end

  # Silences the logger for the duration of the block.
  def silence(temporary_level = Logger::ERROR)
    mutex.synchronize do
      if silencer
        begin
          old_logger_level, self.level = level, temporary_level
          yield self
        ensure
          self.level = old_logger_level
        end
      else
        yield self
      end
    end
  end

  private

  def mutex
    @mutex ||= Mutex.new  # It seems to be threadsafe in MRI only.
  end
end
