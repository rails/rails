begin
  require 'ruby-prof'
rescue LoadError
  $stderr.puts 'Specify ruby-prof as application\'s dependency in Gemfile to run benchmarks.'
  exit
end

module ActiveSupport
  module Testing
    module Performance
      protected
        def run_gc
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
          def measure_mode
            self.class::Mode
          end
          
          def profile
            RubyProf.resume
            yield
          ensure
            RubyProf.pause
          end

          protected
            # overridden by each implementation
            def with_gc_stats
              yield
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
          
          # overridden by each implementation
          def measure; 0; end
        end

        class Objects < Amount
          Mode = RubyProf::ALLOCATIONS if RubyProf.const_defined?(:ALLOCATIONS)
          
          # overridden by each implementation
          def measure; 0; end
        end

        class GcRuns < Amount
          Mode = RubyProf::GC_RUNS if RubyProf.const_defined?(:GC_RUNS)
          
          # overridden by each implementation
          def measure; 0; end
        end

        class GcTime < Time
          Mode = RubyProf::GC_TIME if RubyProf.const_defined?(:GC_TIME)

          # overridden by each implementation
          def measure; 0; end
        end
      end
    end
  end
end

if RUBY_VERSION >= '1.9.2'
  require 'active_support/testing/performance/ruby/yarv'
elsif RUBY_VERSION >= '1.8.6'
  require 'active_support/testing/performance/ruby/mri'
else
  $stderr.puts 'Update your ruby interpreter to be able to run benchmarks.'
  exit
end
