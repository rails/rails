begin
  require 'ruby-prof'
rescue LoadError
  $stderr.puts "Specify ruby-prof as application's dependency in Gemfile to run benchmarks."
  exit
end

module ActiveSupport
  module Testing
    module Performance
      protected
        def run_warmup
          GC.start

          time = Metrics::Time.new
          run_test(time, :benchmark)
          puts "%s (%s warmup)" % [full_test_name, time.format(time.total)]

          GC.start
        end
        
      class Performer; end

      class Profiler < Performer
        def initialize(*args)
          super
          @supported = @metric.measure_mode rescue false
        end

        def run
          return unless @supported

          RubyProf.measure_mode = @metric.measure_mode
          RubyProf.start
          RubyProf.pause
          profile_options[:runs].to_i.times { run_test(@metric, :profile) }
          @data = RubyProf.stop
          @total = @data.threads.values.sum(0) { |method_infos| method_infos.max.total_time }
        end

        def report
          if @supported
            super
          else
            '%20s: unsupported' % @metric.name
          end
        end

        def record
          return unless @supported

          klasses = profile_options[:formats].map { |f| RubyProf.const_get("#{f.to_s.camelize}Printer") }.compact

          klasses.each do |klass|
            fname = output_filename(klass)
            FileUtils.mkdir_p(File.dirname(fname))
            File.open(fname, 'wb') do |file|
              klass.new(@data).print(file, profile_options.slice(:min_percent))
            end
          end
        end

        protected
          def output_filename(printer_class)
            suffix =
              case printer_class.name.demodulize
                when 'FlatPrinter';                 'flat.txt'
                when 'FlatPrinterWithLineNumbers';  'flat_line_numbers.txt'
                when 'GraphPrinter';                'graph.txt'
                when 'GraphHtmlPrinter';            'graph.html'
                when 'GraphYamlPrinter';            'graph.yml'
                when 'CallTreePrinter';             'tree.txt'
                when 'CallStackPrinter';            'stack.html'
                when 'DotPrinter';                  'graph.dot'
                else printer_class.name.sub(/Printer$/, '').underscore
              end

            "#{super()}_#{suffix}"
          end
      end

      module Metrics
        class Base
          def profile
            RubyProf.resume
            yield
          ensure
            RubyProf.pause
          end

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

            # Ruby 1.8 + ruby-prof wrapper (enable/disable stats for Benchmarker)
            elsif GC.respond_to?(:enable_stats)
              def with_gc_stats
                GC.enable_stats
                yield
              ensure
                GC.disable_stats
              end

            else
              def with_gc_stats
                yield
              end
            end
        end
        
        class Time < Base; end
        
        class ProcessTime < Time
          Mode = RubyProf::PROCESS_TIME if RubyProf.const_defined?(:PROCESS_TIME)

          def measure
            RubyProf.measure_process_time
          end
        end

        class WallTime < Time
          Mode = RubyProf::WALL_TIME if RubyProf.const_defined?(:WALL_TIME)

          def measure
            RubyProf.measure_wall_time
          end
        end

        class CpuTime < Time
          Mode = RubyProf::CPU_TIME if RubyProf.const_defined?(:CPU_TIME)

          def initialize(*args)
            # FIXME: yeah my CPU is 2.33 GHz
            RubyProf.cpu_frequency = 2.33e9 unless RubyProf.cpu_frequency > 0
            super
          end

          def measure
            RubyProf.measure_cpu_time
          end
        end

        class Memory < Base
          Mode = RubyProf::MEMORY if RubyProf.const_defined?(:MEMORY)

          # Ruby 1.9 + GCdata patch
          if GC.respond_to?(:malloc_allocated_size)
            def measure
              GC.malloc_allocated_size / 1024.0
            end

          # Ruby 1.8 + ruby-prof wrapper
          elsif RubyProf.respond_to?(:measure_memory)
            def measure
              RubyProf.measure_memory / 1024.0
            end
          end

          def format(measurement)
            '%.2f KB' % measurement
          end
        end

        class Objects < Base
          Mode = RubyProf::ALLOCATIONS if RubyProf.const_defined?(:ALLOCATIONS)

          # Ruby 1.9 + GCdata patch
          if GC.respond_to?(:malloc_allocations)
            def measure
              GC.malloc_allocations
            end

          # Ruby 1.8 + ruby-prof wrapper
          elsif RubyProf.respond_to?(:measure_allocations)
            def measure
              RubyProf.measure_allocations
            end
          end

          def format(measurement)
            measurement.to_i.to_s
          end
        end

        class GcRuns < Base
          Mode = RubyProf::GC_RUNS if RubyProf.const_defined?(:GC_RUNS)

          # Ruby 1.9
          if GC.respond_to?(:count)
            def measure
              GC.count
            end

          # Ruby 1.8 + ruby-prof wrapper
          elsif RubyProf.respond_to?(:measure_gc_runs)
            def measure
              RubyProf.measure_gc_runs
            end
          end

          def format(measurement)
            measurement.to_i.to_s
          end
        end

        class GcTime < Base
          Mode = RubyProf::GC_TIME if RubyProf.const_defined?(:GC_TIME)

          # Ruby 1.9 with GC::Profiler
          if defined?(GC::Profiler) && GC::Profiler.respond_to?(:total_time)
            def measure
              GC::Profiler.total_time
            end

          # Ruby 1.8 + ruby-prof wrapper
          elsif RubyProf.respond_to?(:measure_gc_time)
            def measure
              RubyProf.measure_gc_time / 1000
            end
          end

          def format(measurement)
            '%.2f ms' % measurement
          end
        end
      end
    end
  end
end
