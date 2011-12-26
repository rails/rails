module ActiveSupport
  module Testing
    module Performance
      module Metrics
        class Base
          protected
            def with_gc_stats
              GC::Profiler.enable
              GC.start
              yield
            ensure
              GC::Profiler.disable
            end
        end

        class Memory < DigitalInformationUnit
          # Ruby 1.9 + GCdata patch
          if GC.respond_to?(:malloc_allocated_size)
            def measure
              GC.malloc_allocated_size
            end
          end
        end

        class Objects < Amount
          # Ruby 1.9 + GCdata patch
          if GC.respond_to?(:malloc_allocations)
            def measure
              GC.malloc_allocations
            end
          end
        end

        class GcRuns < Amount
          def measure
            GC.count
          end
        end

        class GcTime < Time
          def measure
            GC::Profiler.total_time
          end
        end
      end
    end
  end
end
