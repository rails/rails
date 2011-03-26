require 'rubinius/agent'

module ActiveSupport
  module Testing
    module Performance
      if !ARGV.include?('--benchmark')
        DEFAULTS.merge!(
          { :metrics => [:wall_time],
            :formats => [:flat, :graph] })
      end
      
      protected
        def run_gc
          GC.run(true)
        end
        
      class Performer; end        

      class Profiler < Performer
        def initialize(*args)
          super
        end
        
        def run
          @profiler = Rubinius::Profiler::Instrumenter.new
          
          @profiler.profile(false) do
            profile_options[:runs].to_i.times { run_test(@metric, :profile) }
          end
          
          @total = @profiler.info[:runtime] / 1000 / 1000 / 1000.0 # seconds
        end
        
        def report
          super
        end
        
        def record
          if(profile_options[:formats].include?(:flat))
            File.open(output_filename('FlatPrinter'), 'wb') do |file|
              @profiler.show(file)
            end
          end
          
          if(profile_options[:formats].include?(:graph))
            @profiler.set_options({:graph => true})
            File.open(output_filename('GraphPrinter'), 'wb') do |file|
              @profiler.show(file)
            end
          end
        end
        
        protected
          def output_filename(printer)
            suffix =
              case printer
                when 'FlatPrinter';                 'flat.txt'
                when 'GraphPrinter';                'graph.txt'
                else printer.sub(/Printer$/, '').underscore
              end

            "#{super()}_#{suffix}"
          end
      end

      module Metrics        
        class Base
          attr_reader :loopback
          
          def profile
            yield
          end

          protected
            # overridden by each implementation
            def with_gc_stats
              @loopback = Rubinius::Agent.loopback
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
            loopback.get("system.memory.counter.objects").last
          end
        end

        class GcRuns < Amount
          def measure
            loopback.get("system.gc.full.count").last + loopback.get("system.gc.young.count").last
          end
        end

        class GcTime < Time
          def measure
            (loopback.get("system.gc.full.wallclock").last + loopback.get("system.gc.young.wallclock").last) / 1000.0
          end
        end
      end
    end
  end
end
