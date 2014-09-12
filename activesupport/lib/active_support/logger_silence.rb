require 'thread'
require 'active_support/core_ext/class/attribute_accessors'
require 'active_support/core_ext/module/aliasing'
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
    Thread.current[thread_hash_level_key]
  end

  def thread_level=(l)
    Thread.current[thread_hash_level_key] = l
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
  
  for severity in Logger::Severity.constants
    class_eval <<-EOT, __FILE__, __LINE__ + 1
      def #{severity.downcase}?                # def debug?
        Logger::#{severity} >= level           #   DEBUG >= level
      end                                      # end
    EOT
  end

  private

  def thread_hash_level_key
    @thread_hash_level_key ||= :"ThreadSafeLogger##{object_id}@level"
  end
end
