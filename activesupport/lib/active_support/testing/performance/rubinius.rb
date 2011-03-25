require 'rubinius/agent'

module ActiveSupport
  module Testing
    module Performance
      protected
        def run_gc
          GC.run(true)
        end

      module Metrics        
        class Base          
          # TODO
          def profile
            yield
          end

          protected
            # overridden by each implementation
            def with_gc_stats
              GC.run(true)
              yield
            end
        end
        
        class Time < Base; end
        
        class ProcessTime < Time
          # unsupported
          def measure; 0; end
        end

        class WallTime < Time
          def measure
            super
          end
        end

        class CpuTime < Time
          # unsupported
          def measure; 0; end
        end

        class Memory < Base
          def measure; 0; end
        end

        class Objects < Amount
          def measure; 0; end
        end

        class GcRuns < Amount
          def measure; 0; end
        end

        class GcTime < Time
          def measure; 0; end
        end
      end
    end
  end
end
