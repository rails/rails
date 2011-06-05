module ActiveSupport
  module Testing
    module Performance
      module Metrics
        class Base
          protected
            # Ruby 1.8 + ruby-prof wrapper (enable/disable stats for Benchmarker)
            if GC.respond_to?(:enable_stats)
              def with_gc_stats
                GC.enable_stats
                GC.start
                yield
              ensure
                GC.disable_stats
              end
            end
        end

        class Memory < DigitalInformationUnit
          # Ruby 1.8 + ruby-prof wrapper
          if RubyProf.respond_to?(:measure_memory)
            def measure
              RubyProf.measure_memory
            end
          end
        end

        class Objects < Amount
          # Ruby 1.8 + ruby-prof wrapper
          if RubyProf.respond_to?(:measure_allocations)
            def measure
              RubyProf.measure_allocations
            end
          end
        end

        class GcRuns < Amount
          # Ruby 1.8 + ruby-prof wrapper
          if RubyProf.respond_to?(:measure_gc_runs)
            def measure
              RubyProf.measure_gc_runs
            end
          end
        end

        class GcTime < Time
          # Ruby 1.8 + ruby-prof wrapper
          if RubyProf.respond_to?(:measure_gc_time)
            def measure
              RubyProf.measure_gc_time / 1000.0 / 1000.0
            end
          end
        end
      end
    end
  end
end
