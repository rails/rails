require 'optparse'
require 'action_controller/integration'

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

      def benchmark(n)
        @quiet = true
        print '  '

        result = Benchmark.realtime do
          n.times do |i|
            run
            print_progress(i)
          end
        end

        puts
        result
      ensure
        @quiet = false
      end

      def say(message)
        puts "  #{message}" unless @quiet
      end

      private
        def define_run_method(script_path)
          script = File.read(script_path)
          source = "def run\n#{script}\nreset!\nend"
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
      puts '%.2f sec, %d requests, %d req/sec' % [elapsed, sandbox.request_count, sandbox.request_count / elapsed]
      puts "\n#{options[:benchmark] ? 'Benchmarking' : 'Profiling'} #{options[:n]}x"

      options[:benchmark] ? benchmark(sandbox) : profile(sandbox)
    end

    def profile(sandbox)
      load_ruby_prof

      results = RubyProf.profile { benchmark(sandbox) }

      show_profile_results results
      results
    end

    def benchmark(sandbox)
      sandbox.request_count = 0
      elapsed = sandbox.benchmark(options[:n]).to_f
      count = sandbox.request_count.to_i
      puts '%.2f sec, %d requests, %d req/sec' % [elapsed, count, count / elapsed]
    end

    def warmup(sandbox)
      Benchmark.realtime { sandbox.run }
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
          require 'ruby-prof'
          #RubyProf.measure_mode = RubyProf::ALLOCATED_OBJECTS
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
