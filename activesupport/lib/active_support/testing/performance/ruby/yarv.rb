module ActiveSupport
  module Testing
    module Performance
      module Metrics
        class Base
          protected
            # Ruby 1.9 with GC::Profiler
            if defined?(GC::Profiler)
              def with_gc_stats
                GC::Profiler.enable
                GC.start
                yield
              ensure
                GC::Profiler.disable
              end
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
          # Ruby 1.9
          if GC.respond_to?(:count)
            def measure
              GC.count
            end
          end
        end

        class GcTime < Time
          # Ruby 1.9 with GC::Profiler
          if defined?(GC::Profiler) && GC::Profiler.respond_to?(:total_time)
            def measure
              GC::Profiler.total_time
            end
          end
        end
      end
    end
  end
end
