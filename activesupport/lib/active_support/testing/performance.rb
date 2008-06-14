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
        :runs => benchmark ? 20 : 4,
        :min_percent => 0.05,
        :metrics => [:process_time, :memory, :allocations],
        :formats => [:flat, :graph_html, :call_tree],
        :output => 'tmp/performance' }

      def self.included(base)
        base.extend ClassMethods
        base.class_inheritable_accessor :profile_options
        base.profile_options = DEFAULTS.dup
      end

      def run(result)
        return if method_name =~ /^default_test$/

        yield(self.class::STARTED, name)
        @_result = result

        run_warmup

        self.class.measure_modes.each do |measure_mode|
          data = run_profile(measure_mode)
          self.class.report_profile_total(data, measure_mode)
          self.class.record_results(full_test_name, data, measure_mode)
          result.add_run
        end

        yield(self.class::FINISHED, name)
      end

      protected
        def full_test_name
          "#{self.class.name}##{@method_name}"
        end

        def run_test
          run_callbacks :setup
          setup
          yield
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

        def run_warmup
          puts
          print full_test_name

          run_test do
            bench = Benchmark.realtime do
              __send__(@method_name)
            end
            puts " (%.2fs warmup)" % bench
          end
        end

        def run_profile(measure_mode)
          RubyProf.benchmarking = profile_options[:benchmark]
          RubyProf.measure_mode = measure_mode

          print '  '
          profile_options[:runs].times do |i|
            run_test do
              begin
                GC.disable
                RubyProf.resume { __send__(@method_name) }
                print '.'
                $stdout.flush
              ensure
                GC.enable
              end
            end
          end

          RubyProf.stop
        end

      module ClassMethods
        def record_results(test_name, data, measure_mode)
          if RubyProf.benchmarking?
            record_benchmark(test_name, data, measure_mode)
          else
            record_profile(test_name, data, measure_mode)
          end
        end

        def report_profile_total(data, measure_mode)
          total_time =
            if RubyProf.benchmarking?
              data
            else
              data.threads.values.sum(0) do |method_infos|
                method_infos.sort.last.total_time
              end
            end

          format =
            case measure_mode
              when RubyProf::PROCESS_TIME, RubyProf::WALL_TIME
                "%.2f seconds"
              when RubyProf::MEMORY
                "%.2f bytes"
              when RubyProf::ALLOCATIONS
                "%d allocations"
              else
                "%.2f #{measure_mode}"
            end

          total = format % total_time
          puts "\n  #{ActiveSupport::Testing::Performance::Util.metric_name(measure_mode)}: #{total}\n"
        end

        def measure_modes
          ActiveSupport::Testing::Performance::Util.measure_modes(profile_options[:metrics])
        end

        def printer_classes
          ActiveSupport::Testing::Performance::Util.printer_classes(profile_options[:formats])
        end

        private
          def record_benchmark(test_name, data, measure_mode)
            bench_filename = "#{profile_options[:output]}/benchmarks.csv"

            if new_file = !File.exist?(bench_filename)
              FileUtils.mkdir_p(File.dirname(bench_filename))
            end

            File.open(bench_filename, 'ab') do |file|
              if new_file
                file.puts 'test,metric,measurement,runs,average,created_at,rails_version,ruby_engine,ruby_version,ruby_patchlevel,ruby_platform'
              end

              file.puts [test_name,
                ActiveSupport::Testing::Performance::Util.metric_name(measure_mode),
                data, profile_options[:runs], data / profile_options[:runs],
                Time.now.utc.xmlschema,
                Rails::VERSION::STRING,
                defined?(RUBY_ENGINE) ? RUBY_ENGINE : 'ruby',
                RUBY_VERSION, RUBY_PATCHLEVEL, RUBY_PLATFORM].join(',')
            end
          end

          def record_profile(test_name, data, measure_mode)
            printer_classes.each do |printer_class|
              fname = output_filename(test_name, printer_class, measure_mode)

              FileUtils.mkdir_p(File.dirname(fname))
              File.open(fname, 'wb') do |file|
                printer_class.new(data).print(file, profile_printer_options)
              end
            end
          end

          # The report filename is test_name + measure_mode + report_type
          def output_filename(test_name, printer_class, measure_mode)
            suffix =
              case printer_class.name.demodulize
                when 'FlatPrinter'; 'flat.txt'
                when 'GraphPrinter'; 'graph.txt'
                when 'GraphHtmlPrinter'; 'graph.html'
                when 'CallTreePrinter'; 'tree.txt'
                else printer_class.name.sub(/Printer$/, '').underscore
              end

            "#{profile_options[:output]}/#{test_name}_#{ActiveSupport::Testing::Performance::Util.metric_name(measure_mode)}_#{suffix}"
          end

          def profile_printer_options
            profile_options.slice(:min_percent)
          end
      end

      module Util
        extend self

        def metric_name(measure_mode)
          case measure_mode
            when RubyProf::PROCESS_TIME; 'process_time'
            when RubyProf::WALL_TIME; 'wall_time'
            when RubyProf::MEMORY; 'memory'
            when RubyProf::ALLOCATIONS; 'allocations'
            else "measure#{measure_mode}"
          end
        end

        def measure_modes(metrics)
          ruby_prof_consts(metrics.map { |m| m.to_s.upcase })
        end

        def printer_classes(formats)
          ruby_prof_consts(formats.map { |f| "#{f.to_s.camelize}Printer" })
        end

        private
          def ruby_prof_consts(names)
            names.map { |name| RubyProf.const_get(name) rescue nil }.compact
          end
      end
    end
  end
end
