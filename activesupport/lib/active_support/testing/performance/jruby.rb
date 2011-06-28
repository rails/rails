require 'jruby/profiler'
require 'java'
java_import java.lang.management.ManagementFactory

module ActiveSupport
  module Testing
    module Performance
      DEFAULTS.merge!(
        if ARGV.include?('--benchmark')
          {:metrics => [:wall_time, :user_time, :memory, :gc_runs, :gc_time]}
        else
          { :metrics => [:wall_time],
            :formats => [:flat, :graph] }
        end).freeze

      protected
        def run_gc
          ManagementFactory.memory_mx_bean.gc
        end

      class Profiler < Performer
        def initialize(*args)
          super
          @supported = @metric.is_a?(Metrics::WallTime)
        end

        def run
          return unless @supported

          @total = time_with_block do
            @data = JRuby::Profiler.profile do
              full_profile_options[:runs].to_i.times { run_test(@metric, :profile) }
            end
          end
        end

        def record
          return unless @supported

          klasses = full_profile_options[:formats].map { |f| JRuby::Profiler.const_get("#{f.to_s.camelize}ProfilePrinter") }.compact

          klasses.each do |klass|
            fname = output_filename(klass)
            FileUtils.mkdir_p(File.dirname(fname))
            file = File.open(fname, 'wb') do |file|
              klass.new(@data).printProfile(file)
            end
          end
        end

        protected
          def output_filename(printer_class)
            suffix =
              case printer_class.name.demodulize
                when 'FlatProfilePrinter';  'flat.txt'
                when 'GraphProfilePrinter'; 'graph.txt'
                else printer_class.name.sub(/ProfilePrinter$/, '').underscore
              end

            "#{super()}_#{suffix}"
          end
      end

      module Metrics
        class Base
          def profile
            yield
          end

          protected
            def with_gc_stats
              ManagementFactory.memory_mx_bean.gc
              yield
            end
        end

        class WallTime < Time
          def measure
            super
          end
        end

        class CpuTime < Time
          def measure
            ManagementFactory.thread_mx_bean.get_current_thread_cpu_time / 1000 / 1000 / 1000.0 # seconds
          end
        end

        class UserTime < Time
          def measure
            ManagementFactory.thread_mx_bean.get_current_thread_user_time / 1000 / 1000 / 1000.0 # seconds
          end
        end

        class Memory < DigitalInformationUnit
          def measure
            ManagementFactory.memory_mx_bean.non_heap_memory_usage.used + ManagementFactory.memory_mx_bean.heap_memory_usage.used
          end
        end

        class GcRuns < Amount
          def measure
            ManagementFactory.garbage_collector_mx_beans.inject(0) { |total_runs, current_gc| total_runs += current_gc.collection_count }
          end
        end

        class GcTime < Time
          def measure
            ManagementFactory.garbage_collector_mx_beans.inject(0) { |total_time, current_gc| total_time += current_gc.collection_time } / 1000.0 # seconds
          end
        end
      end
    end
  end
end
