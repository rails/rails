require 'active_support/concern'
require 'thread_safe'

module LoggerSilence
  extend ActiveSupport::Concern
  
  included do
    cattr_accessor :silencer
    attr_reader :local_levels
    self.silencer = true
  end


  def after_initialize
    @local_levels = ThreadSafe::Cache.new(:initial_capacity => 2)
  end

  def local_log_id
    Thread.current.__id__
  end

  def level
    local_levels[local_log_id] || super
  end

  # Silences the logger for the duration of the block.
  def silence(temporary_level = Logger::ERROR)
    if silencer
      begin
        old_local_level            = local_levels[local_log_id]
        local_levels[local_log_id] = temporary_level

        yield self
      ensure
        if old_local_level
          local_levels[local_log_id] = old_local_level
        else
          local_levels.delete(local_log_id)
        end
      end
    else
      yield self
    end
  end
end