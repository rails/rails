require 'rubinius/agent'

module ActiveSupport
  module Testing
    module Performance
      DEFAULTS.merge!(
        if ARGV.include?('--benchmark')
          {:metrics => [:wall_time, :memory, :objects, :gc_runs, :gc_time]}
        else
          { :metrics => [:wall_time],
            :formats => [:flat, :graph] }
        end).freeze

      protected
        def run_gc
          GC.run(true)
        end

      class Performer; end

      class Profiler < Performer
        def initialize(*args)
          super
          @supported = @metric.is_a?(Metrics::WallTime)
        end

        def run
          return unless @supported

          @profiler = Rubinius::Profiler::Instrumenter.new

          @total = time_with_block do
            @profiler.profile(false) do
              full_profile_options[:runs].to_i.times { run_test(@metric, :profile) }
            end
          end
        end

        def record
          return unless @supported

          if(full_profile_options[:formats].include?(:flat))
            create_path_and_open_file(:flat) do |file|
              @profiler.show(file)
            end
          end

          if(full_profile_options[:formats].include?(:graph))
            create_path_and_open_file(:graph) do |file|
              @profiler.show(file)
            end
          end
        end

        protected
          def create_path_and_open_file(printer_name)
            fname = "#{output_filename}_#{printer_name}.txt"
            FileUtils.mkdir_p(File.dirname(fname))
            File.open(fname, 'wb') do |file|
              yield(file)
            end
          end
      end

      module Metrics
        class Base
          attr_reader :loopback

          def profile
            yield
          end

          protected
            def with_gc_stats
              @loopback = Rubinius::Agent.loopback
              GC.run(true)
              yield
            end
        end

        class WallTime < Time
          def measure
            super
          end
        end

        class Memory < DigitalInformationUnit
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
