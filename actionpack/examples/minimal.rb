# Pass NEW=1 to run with the new Base
ENV['RAILS_ENV'] ||= 'production'
ENV['NO_RELOAD'] ||= '1'

$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../lib"
require 'action_controller'
require 'action_controller/new_base' if ENV['NEW']
require 'benchmark'

class BaseController < ActionController::Base
  def index
    render :text => ''
  end
end

class Runner
  def initialize(app)
    @app = app
  end

  def call(env)
    env['n'].to_i.times { @app.call(env) }
    @app.call(env).tap { |response| report(env, response) }
  end

  def report(env, response)
    out = env['rack.errors']
    out.puts response[0], response[1].to_yaml, '---'
    response[2].each { |part| out.puts part }
    out.puts '---'
  end
end

n = (ENV['N'] || 1000).to_i
input = StringIO.new('')

elapsed = Benchmark.realtime do
  Runner.new(BaseController.action(:index)).
    call('n' => n, 'rack.input' => input, 'rack.errors' => $stdout)
end
puts "%dms elapsed, %d req/sec, %.2f msec/req" %
  [1000 * elapsed, n / elapsed, 1000 * elapsed / n]
