require 'rubygems'
gem 'ruby-prof', '>= 0.6.1'
require 'ruby-prof'

require 'fileutils'
require 'rails/version'

module ActiveSupport
  module Testing
    module Performance
      benchmark = ARGV.include?('--benchmark')  # HAX for rake test

      DEFAULTS = {
        :benchmark => benchmark,
        :runs => benchmark ? 10 : 1,
        :min_percent => 0.02,
        :metrics => [:process_time, :wall_time, :cpu_time, :memory, :objects],
        :formats => [:flat, :graph_html, :call_tree],
        :output => 'tmp/performance'
      }

      def self.included(base)
        base.class_inheritable_hash :profile_options
        base.profile_options = DEFAULTS.dup
      end

      def full_test_name
        "#{self.class.name}##{method_name}"
      end

      def run(result)
        return if method_name =~ /^default_test$/

        yield(self.class::STARTED, name)
        @_result = result

        run_warmup
        profile_options[:metrics].each do |metric_name|
          if klass = Metrics[metric_name.to_sym]
            run_profile(klass.new)
            result.add_run
          else
            $stderr.puts "Skipping unknown metric #{metric_name.inspect}. Expected :process_time, :wall_time, :cpu_time, :memory, or :objects."
          end
        end

        yield(self.class::FINISHED, name)
      end

      def run_test(metric, mode)
        run_callbacks :setup
        setup
        metric.send(mode) { __send__ @method_name }
      rescue ::Test::Unit::AssertionFailedError => e
        add_failure(e.message, e.backtrace)
      rescue StandardError, ScriptError
        add_error($!)
      ensure
        begin
          teardown
          run_callbacks :teardown, :enumerator => :reverse_each
        rescue ::Test::Unit::AssertionFailedError => e
          add_failure(e.message, e.backtrace)
        rescue StandardError, ScriptError
          add_error($!)
        end
      end

      protected
        def run_warmup
          time = Metrics::Time.new
          run_test(time, :benchmark)
          puts "%s (%s warmup)" % [full_test_name, time.format(time.total)]
        end

        def run_profile(metric)
          klass = profile_options[:benchmark] ? Benchmarker : Profiler
          performer = klass.new(self, metric)

          performer.run
          puts performer.report
          performer.record
        end

      class Performer
        delegate :profile_options, :full_test_name, :to => :@harness

        def initialize(harness, metric)
          @harness, @metric = harness, metric
        end

        def report
          rate = @total / profile_options[:runs]
          '%20s: %s/run' % [@metric.name, @metric.format(rate)]
        end
      end

      class Benchmarker < Performer
        def run
          profile_options[:runs].times { @harness.run_test(@metric, :benchmark) }
          @total = @metric.total
        end

        def record
          with_output_file do |file|
            file.puts [full_test_name, @metric.name,
              @metric.total, profile_options[:runs],
              @metric.total / profile_options[:runs],
              Time.now.utc.xmlschema,
              Rails::VERSION::STRING,
              defined?(RUBY_ENGINE) ? RUBY_ENGINE : 'ruby',
              RUBY_VERSION, RUBY_PATCHLEVEL, RUBY_PLATFORM].join(',')
          end
        end

        protected
          HEADER = 'test,metric,measurement,runs,average,created_at,rails_version,ruby_engine,ruby_version,ruby_patchlevel,ruby_platform'

          def with_output_file
            fname = "#{profile_options[:output]}/benchmarks.csv"

            if new = !File.exist?(fname)
              FileUtils.mkdir_p(File.dirname(fname))
            end

            File.open(fname, 'ab') do |file|
              file.puts(HEADER) if new
              yield file
            end
          end
      end

      class Profiler < Performer
        def run
          @runs.times { @harness.run_test(@metric, :profile) }
          @data = RubyProf.stop
          @total = @data.threads.values.sum(0) { |method_infos| method_infos.sort.last.total_time }
        end

        def record(path)
          klasses = profile_options[:formats].map { |f| RubyProf.const_get("#{f.to_s.camelize}Printer") }.compact

          klasses.each do |klass|
            fname = output_filename(metric, klass)
            FileUtils.mkdir_p(File.dirname(fname))
            File.open(fname, 'wb') do |file|
              klass.new(@data).print(file, profile_options.slice(:min_percent))
            end
          end
        end

        protected
          def output_filename(metric, printer_class)
            suffix =
              case printer_class.name.demodulize
                when 'FlatPrinter'; 'flat.txt'
                when 'GraphPrinter'; 'graph.txt'
                when 'GraphHtmlPrinter'; 'graph.html'
                when 'CallTreePrinter'; 'tree.txt'
                else printer_class.name.sub(/Printer$/, '').underscore
              end

            "#{profile_options[:output]}/#{full_test_name}_#{metric.name}_#{suffix}"
          end
      end

      module Metrics
        def self.[](name)
          klass = const_get(name.to_s.camelize)
          klass if klass::Mode
        rescue NameError
          nil
        end

        class Base
          attr_reader :total

          def initialize
            @total = 0
          end

          def name
            @name ||= self.class.name.demodulize.underscore
          end

          def benchmark
            with_gc_stats do
              before = measure
              yield
              @total += (measure - before)
            end
          end

          def profile
            RubyProf.measure_mode = Mode
            RubyProf.resume { yield }
          end

          protected
            if GC.respond_to?(:enable_stats)
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

        class Time < Base
          def measure
            ::Time.now.to_f
          end

          def format(measurement)
            if measurement < 2
              '%d ms' % (measurement * 1000)
            else
              '%.2f sec' % measurement
            end
          end
        end

        class ProcessTime < Time
          Mode = RubyProf::PROCESS_TIME

          def measure
            RubyProf.measure_process_time
          end
        end

        class WallTime < Time
          Mode = RubyProf::WALL_TIME

          def measure
            RubyProf.measure_wall_time
          end
        end

        class CpuTime < Time
          Mode = RubyProf::CPU_TIME

          def initialize(*args)
            # FIXME: yeah my CPU is 2.33 GHz
            RubyProf.cpu_frequency = 2.33e9
            super
          end

          def measure
            RubyProf.measure_cpu_time
          end
        end

        class Memory < Base
          Mode = RubyProf::MEMORY

          if RubyProf.respond_to?(:measure_memory)
            def measure
              RubyProf.measure_memory
            end
          elsif GC.respond_to?(:allocated_size)
            def measure
              GC.allocated_size
            end
          elsif GC.respond_to?(:malloc_allocated_size)
            def measure
              GC.malloc_allocated_size
            end
          end

          def format(measurement)
            '%.2f KB' % (measurement / 1024.0)
          end
        end

        class Objects < Base
          Mode = RubyProf::ALLOCATIONS

          if RubyProf.respond_to?(:measure_allocations)
            def measure
              RubyProf.measure_allocations
            end
          elsif ObjectSpace.respond_to?(:allocated_objects)
            def measure
              ObjectSpace.allocated_objects
            end
          end

          def format(measurement)
            measurement.to_s
          end
        end
      end
    end
  end
end
