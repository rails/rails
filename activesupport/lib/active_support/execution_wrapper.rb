require 'active_support/callbacks'

module ActiveSupport
  class ExecutionWrapper
    include ActiveSupport::Callbacks

    define_callbacks :run
    define_callbacks :complete

    def self.to_run(*args, &block)
      set_callback(:run, *args, &block)
    end

    def self.to_complete(*args, &block)
      set_callback(:complete, *args, &block)
    end

    # Run this execution.
    #
    # Returns an instance, whose +complete!+ method *must* be invoked
    # after the work has been performed.
    #
    # Where possible, prefer +wrap+.
    def self.run!
      new.tap(&:run!)
    end

    # Perform the work in the supplied block as an execution.
    def self.wrap
      return yield if active?

      state = run!
      begin
        yield
      ensure
        state.complete!
      end
    end

    class << self # :nodoc:
      attr_accessor :active
    end

    def self.inherited(other) # :nodoc:
      super
      other.active = Concurrent::Hash.new(0)
    end

    self.active = Concurrent::Hash.new(0)

    def self.active? # :nodoc:
      @active[Thread.current] > 0
    end

    def run! # :nodoc:
      self.class.active[Thread.current] += 1
      run_callbacks(:run)
    end

    # Complete this in-flight execution. This method *must* be called
    # exactly once on the result of any call to +run!+.
    #
    # Where possible, prefer +wrap+.
    def complete!
      run_callbacks(:complete)
      self.class.active.delete Thread.current if (self.class.active[Thread.current] -= 1) == 0
    end
  end
end
