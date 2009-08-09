# Pass NEW=1 to run with the new Base
ENV['RAILS_ENV'] ||= 'production'
ENV['NO_RELOAD'] ||= '1'

$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../lib"
$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../../activesupport/lib"
require 'action_controller'
require 'action_controller/new_base' if ENV['NEW']
require 'action_view'
require 'benchmark'

class Runner
  def initialize(app, output)
    @app, @output = app, output
  end

  def puts(*)
    super if @output
  end

  def call(env)
    env['n'].to_i.times { @app.call(env) }
    @app.call(env).tap { |response| report(env, response) }
  end

  def report(env, response)
    return unless ENV["DEBUG"]
    out = env['rack.errors']
    out.puts response[0], response[1].to_yaml, '---'
    response[2].each { |part| out.puts part }
    out.puts '---'
  end

  def self.puts(*)
    super if @output
  end

  def self.run(app, n, label, output = true)
    @output = output
    puts label, '=' * label.size if label
    env = Rack::MockRequest.env_for("/").merge('n' => n, 'rack.input' => StringIO.new(''), 'rack.errors' => $stdout)
    t = Benchmark.realtime { new(app, output).call(env) }
    puts "%d ms / %d req = %.1f usec/req" % [10**3 * t, n, 10**6 * t / n]
    puts
  end
end


N = (ENV['N'] || 1000).to_i

module ActionController::Rails2Compatibility
  instance_methods.each do |name|
    remove_method name
  end
end

class BasePostController < ActionController::Base
  append_view_path "#{File.dirname(__FILE__)}/views"

  def overhead
    self.response_body = ''
  end

  def index
    render :text => ''
  end

  def partial
    render :partial => "/partial"
  end

  def many_partials
    render :partial => "/many_partials"
  end

  def partial_collection
    render :partial => "/collection", :collection => [1,2,3,4,5,6,7,8,9,10]
  end

  def show_template
    render :template => "template"
  end
end

OK = [200, {}, []]
MetalPostController = lambda { OK }

class HttpPostController < ActionController::Metal
  def index
    self.response_body = ''
  end
end

unless ENV["PROFILE"]
  Runner.run(BasePostController.action(:overhead), N, 'overhead', false)
  Runner.run(BasePostController.action(:index), N, 'index', false)
  Runner.run(BasePostController.action(:partial), N, 'partial', false)
  Runner.run(BasePostController.action(:many_partials), N, 'many_partials', false)
  Runner.run(BasePostController.action(:partial_collection), N, 'collection', false)
  Runner.run(BasePostController.action(:show_template), N, 'template', false)

  (ENV["M"] || 1).to_i.times do
    Runner.run(BasePostController.action(:overhead), N, 'overhead')
    Runner.run(BasePostController.action(:index), N, 'index')
    Runner.run(BasePostController.action(:partial), N, 'partial')
    Runner.run(BasePostController.action(:many_partials), N, 'many_partials')
    Runner.run(BasePostController.action(:partial_collection), N, 'collection')
    Runner.run(BasePostController.action(:show_template), N, 'template')
  end
else
  Runner.run(BasePostController.action(:many_partials), N, 'many_partials')
  require "ruby-prof"
  RubyProf.start
  Runner.run(BasePostController.action(:many_partials), N, 'many_partials')
  result = RubyProf.stop
  printer = RubyProf::CallStackPrinter.new(result)
  printer.print(File.open("output.html", "w"))
end