require 'jruby/profiler'
require 'java' 
import java.lang.management.ManagementFactory

module ActiveSupport
  module Testing
    module Performance
      if ARGV.include?('--benchmark')
        DEFAULTS.merge!({:metrics => [:wall_time, :user_time, :memory, :gc_runs, :gc_time, :ola]})
      else
        DEFAULTS.merge!(
          { :metrics => [:wall_time],
            :formats => [:flat, :graph] })
      end
      
      protected
        def run_gc
          ManagementFactory.memory_mx_bean.gc
        end
        
      class Performer; end        

      class Profiler < Performer
        def run
        end
        
        def report
        end
        
        def record
        end
        
        protected
          def output_filename(printer_class)
          end
      end

      module Metrics        
        class Base
          def profile
          end

          protected
            def with_gc_stats
            end
            
        class Time < Base; end
        
        class ProcessTime < Time
          def measure; 0; end
        end

        class WallTime < Time
          def measure
            super
          end
        end

        class CpuTime < Time
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
end
