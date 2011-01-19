module ActiveSupport
  module Testing
    module GarbageCollection
      def self.included(base)
        base.teardown :scrub_leftover_instance_variables

        base.setup :begin_gc_deferment
        base.teardown :reconsider_gc_deferment
      end

      private

      RESERVED_INSTANCE_VARIABLES = %w(@test_passed @passed @method_name @__name__ @_result).map(&:to_sym)

      def scrub_leftover_instance_variables
        (instance_variables.map(&:to_sym) - RESERVED_INSTANCE_VARIABLES).each do |var|
          remove_instance_variable(var)
        end
      end

      # Minimum interval, in seconds, at which to run GC. Might be less
      # frequently than this, if a single test takes longer than this to
      # run.
      DEFERRED_GC_THRESHOLD = (ENV['DEFERRED_GC_THRESHOLD'] || 1.0).to_f

      @@last_gc_run = Time.now

      def begin_gc_deferment
        GC.disable if DEFERRED_GC_THRESHOLD > 0
      end

      def reconsider_gc_deferment
        if DEFERRED_GC_THRESHOLD > 0 && Time.now - @@last_gc_run >= DEFERRED_GC_THRESHOLD
          GC.enable
          GC.start
          GC.disable

          @@last_gc_run = Time.now
        end
      end
    end
  end
end
