require "active_support/execution_wrapper"

module ActiveSupport
  #--
  # This class defines several callbacks:
  #
  #   to_prepare -- Run once at application startup, and also from
  #   +to_run+.
  #
  #   to_run -- Run before a work run that is reloading. If
  #   +reload_classes_only_on_change+ is true (the default), the class
  #   unload will have already occurred.
  #
  #   to_complete -- Run after a work run that has reloaded. If
  #   +reload_classes_only_on_change+ is false, the class unload will
  #   have occurred after the work run, but before this callback.
  #
  #   before_class_unload -- Run immediately before the classes are
  #   unloaded.
  #
  #   after_class_unload -- Run immediately after the classes are
  #   unloaded.
  #
  class Reloader < ExecutionWrapper
    define_callbacks :prepare

    define_callbacks :class_unload

    def self.to_prepare(*args, &block)
      set_callback(:prepare, *args, &block)
    end

    def self.before_class_unload(*args, &block)
      set_callback(:class_unload, *args, &block)
    end

    def self.after_class_unload(*args, &block)
      set_callback(:class_unload, :after, *args, &block)
    end

    to_run(:after) { self.class.prepare! }

    # Initiate a manual reload
    def self.reload!
      executor.wrap do
        new.tap do |instance|
          begin
            instance.run!
          ensure
            instance.complete!
          end
        end
      end
      prepare!
    end

    def self.run! # :nodoc:
      if check!
        super
      else
        Null
      end
    end

    # Run the supplied block as a work unit, reloading code as needed
    def self.wrap
      executor.wrap do
        super
      end
    end

    class_attribute :executor
    class_attribute :check

    self.executor = Executor
    self.check = lambda { false }

    def self.check! # :nodoc:
      @should_reload ||= check.call
    end

    def self.reloaded! # :nodoc:
      @should_reload = false
    end

    def self.prepare! # :nodoc:
      new.run_callbacks(:prepare)
    end

    def initialize
      super
      @locked = false
    end

    # Acquire the ActiveSupport::Dependencies::Interlock unload lock,
    # ensuring it will be released automatically
    def require_unload_lock!
      unless @locked
        ActiveSupport::Dependencies.interlock.start_unloading
        @locked = true
      end
    end

    # Release the unload lock if it has been previously obtained
    def release_unload_lock!
      if @locked
        @locked = false
        ActiveSupport::Dependencies.interlock.done_unloading
      end
    end

    def run! # :nodoc:
      super
      release_unload_lock!
    end

    def class_unload!(&block) # :nodoc:
      require_unload_lock!
      run_callbacks(:class_unload, &block)
    end

    def complete! # :nodoc:
      super
      self.class.reloaded!
    ensure
      release_unload_lock!
    end
  end
end
