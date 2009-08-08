$:.push File.join(File.dirname(__FILE__), "..", "lib")
require "action_controller"

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

  def self.run(app, n, label = nil)
    puts '=' * label.size, label, '=' * label.size if label
    env = Rack::MockRequest.env_for("/").merge('n' => n, 'rack.input' => StringIO.new(''), 'rack.errors' => $stdout)
    t = Benchmark.realtime { new(app).call(env) }
    puts "%d ms / %d req = %.1f usec/req" % [10**3 * t, n, 10**6 * t / n]
    puts
  end
end
