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
          
          def loopback
            @loopback ||= Rubinius::Agent.loopback
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
          def measure
            loopback.get("system.memory.counter.bytes").last
          end
        end

        class Objects < Amount
          def measure
            loopback.get("system.memory.counter.bytes").last
          end
        end

        class GcRuns < Amount
          def measure
            loopback.get("system.gc.full.count").last + loopback.get("system.gc.young.count").last
          end
        end

        class GcTime < Time
          def measure
            loopback.get("system.gc.full.wallclock").last + loopback.get("system.gc.young.wallclock").last
          end
        end
      end
    end
  end
end
