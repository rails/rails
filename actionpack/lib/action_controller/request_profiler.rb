require 'optparse'

module ActionController
  class RequestProfiler
    # Wrap up the integration session runner.
    class Sandbox
      include Integration::Runner

      def self.benchmark(n, script)
        new(script).benchmark(n)
      end

      def initialize(script_path)
        @quiet = false
        define_run_method(script_path)
        reset!
      end

      def benchmark(n, profiling = false)
        @quiet = true
        print '  '

        ms = Benchmark.ms do
          n.times do |i|
            run(profiling)
            print_progress(i)
          end
        end

        puts
        ms
      ensure
        @quiet = false
      end

      def say(message)
        puts "  #{message}" unless @quiet
      end

      private
        def define_run_method(script_path)
          script = File.read(script_path)

          source = <<-end_source
            def run(profiling = false)
              if profiling
                RubyProf.resume do
                  #{script}
                end
              else
                #{script}
              end

              old_request_count = request_count
              reset!
              self.request_count = old_request_count
            end
          end_source

          instance_eval source, script_path, 1
        end

        def print_progress(i)
          print "\n  " if i % 60 == 0
          print ' ' if i % 10 == 0
          print '.'
          $stdout.flush
        end
    end


    attr_reader :options

    def initialize(options = {})
      @options = default_options.merge(options)
    end


    def self.run(args = nil, options = {})
      profiler = new(options)
      profiler.parse_options(args) if args
      profiler.run
    end

    def run
      sandbox = Sandbox.new(options[:script])

      puts 'Warming up once'

      elapsed = warmup(sandbox)
      puts '%.0f ms, %d requests, %d req/sec' % [elapsed, sandbox.request_count, 1000 * sandbox.request_count / elapsed]
      puts "\n#{options[:benchmark] ? 'Benchmarking' : 'Profiling'} #{options[:n]}x"

      options[:benchmark] ? benchmark(sandbox) : profile(sandbox)
    end

    def profile(sandbox)
      load_ruby_prof

      benchmark(sandbox, true)
      results = RubyProf.stop

      show_profile_results results
      results
    end

    def benchmark(sandbox, profiling = false)
      sandbox.request_count = 0
      elapsed = sandbox.benchmark(options[:n], profiling)
      count = sandbox.request_count.to_i
      puts '%.0f ms, %d requests, %d req/sec' % [elapsed, count, 1000 * count / elapsed]
    end

    def warmup(sandbox)
      Benchmark.ms { sandbox.run(false) }
    end

    def default_options
      { :n => 100, :open => 'open %s &' }
    end

    # Parse command-line options
    def parse_options(args)
      OptionParser.new do |opt|
        opt.banner = "USAGE: #{$0} [options] [session script path]"

        opt.on('-n', '--times [100]', 'How many requests to process. Defaults to 100.') { |v| options[:n] = v.to_i if v }
        opt.on('-b', '--benchmark', 'Benchmark instead of profiling') { |v| options[:benchmark] = v }
        opt.on('-m', '--measure [mode]', 'Which ruby-prof measure mode to use: process_time, wall_time, cpu_time, allocations, or memory. Defaults to process_time.') { |v| options[:measure] = v }
        opt.on('--open [CMD]', 'Command to open profile results. Defaults to "open %s &"') { |v| options[:open] = v }
        opt.on('-h', '--help', 'Show this help') { puts opt; exit }

        opt.parse args

        if args.empty?
          puts opt
          exit
        end
        options[:script] = args.pop
      end
    end

    protected
      def load_ruby_prof
        begin
          gem 'ruby-prof', '>= 0.6.1'
          require 'ruby-prof'
          if mode = options[:measure]
            RubyProf.measure_mode = RubyProf.const_get(mode.upcase)
          end
        rescue LoadError
          abort '`gem install ruby-prof` to use the profiler'
        end
      end

      def show_profile_results(results)
        File.open "#{RAILS_ROOT}/tmp/profile-graph.html", 'w' do |file|
          RubyProf::GraphHtmlPrinter.new(results).print(file)
          `#{options[:open] % file.path}` if options[:open]
        end

        File.open "#{RAILS_ROOT}/tmp/profile-flat.txt", 'w' do |file|
          RubyProf::FlatPrinter.new(results).print(file)
          `#{options[:open] % file.path}` if options[:open]
        end
      end
  end
end
