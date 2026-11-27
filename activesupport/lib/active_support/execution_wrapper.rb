# frozen_string_literal: true

require "active_support/error_reporter"
require "active_support/callbacks"

module ActiveSupport
  class ExecutionWrapper
    include ActiveSupport::Callbacks

    Null = Object.new # :nodoc:
    def Null.complete! # :nodoc:
    end
    Null.freeze

    define_callbacks :run
    define_callbacks :complete

    class << self
      attr_reader :active_key # :nodoc:
      attr_accessor :default_timeout
    end

    attr_reader :deadline

    def self.inherited(subclass)
      subclass.class_eval { @active_key = :"active_execution_wrapper_#{object_id}" }
    end

    def self.to_run(*args, &block)
      set_callback(:run, *args, &block)
    end

    def self.to_complete(*args, &block)
      set_callback(:complete, *args, &block)
    end

    class Hook # :nodoc:
      def initialize(hook, pass_target)
        @hook = hook
        @pass_target = pass_target
      end
    end

    class RunHook < Hook # :nodoc:
      def before(target)
        state = if @pass_target
          @hook.run(target)
        else
          @hook.run
        end
        target.hook_state[@hook] = state
      end
    end

    class CompleteHook < Hook # :nodoc:
      def before(target)
        hook_state = target.hook_state
        if hook_state.key?(@hook)
          state = hook_state[@hook]
          if @pass_target
            @hook.complete target, state
          else
            @hook.complete state
          end
        end
      end
      alias after before
    end

    # Register an object to be invoked during both the `run` and
    # `complete` steps.
    #
    # `hook.complete` will be passed the value returned from `hook.run`,
    # and will only be invoked if `run` has previously been called.
    # (Mostly, this means it won't be invoked if an exception occurs in
    # a preceding `to_run` block; all ordinary `to_complete` blocks are
    # invoked in that situation.)
    def self.register_hook(hook, outer: false, instance: false)
      if outer
        to_run RunHook.new(hook, instance), prepend: true
        to_complete :after, CompleteHook.new(hook, instance)
      else
        to_run RunHook.new(hook, instance)
        to_complete CompleteHook.new(hook, instance)
      end
    end

    # Run this execution.
    #
    # Returns an instance, whose `complete!` method **must** be invoked
    # after the work has been performed.
    #
    # Where possible, prefer `wrap`.
    def self.run!(reset: false)
      if reset
        lost_instance = IsolatedExecutionState.delete(active_key)
        lost_instance&.complete!
      else
        return Null if active?
      end

      new.tap do |instance|
        success = nil
        begin
          instance.run!
          success = true
        ensure
          instance.complete! unless success
        end
      end
    end

    # Perform the work in the supplied block as an execution.
    def self.wrap(source: "application.active_support")
      return yield if active?

      instance = run!
      begin
        yield
      rescue Exception => error
        error_reporter&.report(error, handled: false, source: source)
        raise
      ensure
        instance.complete!
      end
    end

    def self.perform # :nodoc:
      instance = new
      instance.run
      begin
        yield
      ensure
        instance.complete
      end
    end

    def self.error_reporter # :nodoc:
      ActiveSupport.error_reporter
    end

    def self.active? # :nodoc:
      IsolatedExecutionState.key?(active_key)
    end

    def self.deadline
      IsolatedExecutionState[active_key]&.deadline
    end

    def run! # :nodoc:
      @deadline = self.class.default_timeout ? Deadline.new(self.class.default_timeout) : Deadline::Null
      IsolatedExecutionState[self.class.active_key] = self
      run
    end

    def run # :nodoc:
      run_callbacks(:run)
    end

    # Complete this in-flight execution. This method **must** be called
    # exactly once on the result of any call to `run!`.
    #
    # Where possible, prefer `wrap`.
    def complete!
      complete
    ensure
      @deadline.close
      IsolatedExecutionState.delete(self.class.active_key)
    end

    def complete # :nodoc:
      run_callbacks(:complete)
    end

    def hook_state # :nodoc:
      @_hook_state ||= {}
    end
  end
end
