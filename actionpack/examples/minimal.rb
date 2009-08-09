$:.push File.join(File.dirname(__FILE__), "..", "lib")
$:.push File.join(File.dirname(__FILE__), "..", "..", "activesupport", "lib")
require "action_controller"

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
    if ENV["DEBUG"]
      out = env['rack.errors']
      p response.headers
      out.puts response.status, response.headers.to_yaml, '---'
      response.body.each { |part| out.puts part }
      out.puts '---'
    end
  end

  def self.puts(*)
    super if @output
  end

  def self.run(app, n, label = nil, uri = "/", output = true)
    @output = output
    puts label, '=' * label.size if label
    env = Rack::MockRequest.env_for(uri).merge('n' => n, 'rack.input' => StringIO.new(''), 'rack.errors' => $stdout)
    t = Benchmark.realtime { new(app, output).call(env) }
    puts "%d ms / %d req = %.1f usec/req" % [10**3 * t, n, 10**6 * t / n]
    puts
  end
end

N = (ENV['N'] || 1000).to_i

class BasePostController < ActionController::Base
  append_view_path "#{File.dirname(__FILE__)}/views"

  def index
    render :text => 'Hello'
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

# p BasePostController.call(Rack::MockRequest.env_for("/?action=index").merge("REQUEST_URI" => "/")).body

Runner.run(BasePostController, N, 'index', "/?action=index", false)
Runner.run(BasePostController, N, 'partial', "/?action=partial", false)
Runner.run(BasePostController, N, 'many partials', "/?action=many_partials", false)
Runner.run(BasePostController, N, 'collection', "/?action=partial_collection", false)
Runner.run(BasePostController, N, 'template', "/?action=show_template", false)

(ENV["M"] || 1).to_i.times do
  Runner.run(BasePostController, N, 'index', "/?action=index")
  Runner.run(BasePostController, N, 'partial', "/?action=partial")
  Runner.run(BasePostController, N, 'many partials', "/?action=many_partials")
  Runner.run(BasePostController, N, 'collection', "/?action=partial_collection")
  Runner.run(BasePostController, N, 'template', "/?action=show_template")
end
  # Runner.run(BasePostController.action(:many_partials), N, 'index')
  # Runner.run(BasePostController.action(:many_partials), N, 'many_partials')
  # Runner.run(BasePostController.action(:partial_collection), N, 'collection')
  # Runner.run(BasePostController.action(:show_template), N, 'template')
