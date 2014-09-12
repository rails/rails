require 'active_support/concern'

module LoggerSilence
  extend ActiveSupport::Concern
  
  included do
    cattr_accessor :silencer
    self.silencer = true
    alias_method_chain :level, :threadsafety
    alias_method_chain :add, :threadsafety
  end

  def thread_level
    Thread.current[:logger_level]
  end

  def thread_level=(l)
    Thread.current[:logger_level] = l
  end

  def level_with_threadsafety
    thread_level || level_without_threadsafety
  end

  def add_with_threadsafety(severity, message = nil, progname = nil, &block)
    return true if @logdev.nil? or (severity || UNKNOWN) < level
    add_without_threadsafety(severity, message, progname, &block)
  end

  # Silences the logger for the duration of the block.
  def silence(temporary_level = Logger::ERROR)
    if silencer
      begin
        self.thread_level = temporary_level
        yield self
      ensure
        self.thread_level = nil
      end
    else
      yield self
    end
  end
end
