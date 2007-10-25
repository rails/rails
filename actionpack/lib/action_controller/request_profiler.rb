require 'optparse'

module ActionController
  class RequestProfiler
    # CGI with stubbed environment and standard input.
    class StubCGI < CGI
      attr_accessor :env_table, :stdinput

      def initialize(env_table, stdinput)
        @env_table = env_table
        super
        @stdinput = stdinput
      end
    end

    # Stripped-down dispatcher.
    class Sandbox
      attr_accessor :env, :body

      def self.benchmark(n, env, body)
        Benchmark.realtime { n.times { new(env, body).dispatch } }
      end

      def initialize(env, body)
        @env, @body = env, body
      end

      def dispatch
        cgi = StubCGI.new(env, StringIO.new(body))

        request = CgiRequest.new(cgi)
        response = CgiResponse.new(cgi)

        controller = Routing::Routes.recognize(request)
        controller.process(request, response)
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
      warmup
      options[:benchmark] ? benchmark : profile
    end

    def profile
      load_ruby_prof

      results = RubyProf.profile { benchmark }

      show_profile_results results
      results
    end

    def benchmark
      puts '%d req/sec' % (options[:n] / Sandbox.benchmark(options[:n], env, body))
    end

    def warmup
      puts "#{options[:benchmark] ? 'Benchmarking' : 'Profiling'} #{options[:n]}x"
      puts "\nrequest headers: #{env.to_yaml}"

      response = Sandbox.new(env, body).dispatch

      puts "\nresponse body: #{response.body[0...100]}#{'[...]' if response.body.size > 100}"
      puts "\nresponse headers: #{response.headers.to_yaml}"
      puts
    end


    def uri
      URI.parse(options[:uri])
    rescue URI::InvalidURIError
      URI.parse(default_uri)
    end

    def default_uri
      '/benchmarks/hello'
    end

    def env
      @env ||= default_env
    end

    def default_env
      defaults = {
        'HTTP_HOST'      => "#{uri.host || 'localhost'}:#{uri.port || 3000}",
        'REQUEST_URI'    => uri.path,
        'REQUEST_METHOD' => method,
        'CONTENT_LENGTH' => body.size }

      if fixture = options[:fixture]
        defaults['CONTENT_TYPE'] = "multipart/form-data; boundary=#{extract_multipart_boundary(fixture)}"
      end

      defaults
    end

    def method
      options[:method] || (options[:fixture] ? 'POST' : 'GET')
    end

    def body
      options[:fixture] ? File.read(options[:fixture]) : ''
    end


    def default_options
      { :n => 1000, :open => 'open %s &' }
    end

    # Parse command-line options
    def parse_options(args)
      OptionParser.new do |opt|
        opt.banner = "USAGE: #{$0} uri [options]"

        opt.on('-u', '--uri [URI]', 'Request URI. Defaults to http://localhost:3000/benchmarks/hello') { |v| options[:uri] = v }
        opt.on('-n', '--times [0000]', 'How many requests to process. Defaults to 1000.') { |v| options[:n] = v.to_i }
        opt.on('--method [GET]', 'HTTP request method. Defaults to GET.') { |v| options[:method] = v.upcase }
        opt.on('--fixture [FILE]', 'Path to POST fixture file') { |v| options[:fixture] = v }
        opt.on('--benchmark', 'Benchmark instead of profiling') { |v| options[:benchmark] = v }
        opt.on('--open [CMD]', 'Command to open profile results. Defaults to "open %s &"') { |v| options[:open] = v }
        opt.on('-h', '--help', 'Show this help') { puts opt; exit }

        opt.parse args
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

      def extract_multipart_boundary(path)
        File.open(path) { |f| f.readline }
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
