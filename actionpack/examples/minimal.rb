$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../lib"
require 'action_controller'
require 'action_controller/new_base' if ENV['NEW']
require 'benchmark'

class BaseController < ActionController::Base
  def index
    render :text => ''
  end
end

n = (ENV['N'] || 10000).to_i
input = StringIO.new('')

def call_index(controller, input, n)
  n.times do
    controller.action(:index).call({ 'rack.input' => input })
  end

  puts controller.name
  status, headers, body = controller.action(:index).call({ 'rack.input' => input })

  puts status
  puts headers.to_yaml
  puts '---'
  body.each do |part|
    puts part
  end
  puts '---'
end

elapsed = Benchmark.realtime { call_index BaseController, input, n }

puts "%dms elapsed, %d requests/sec" % [1000 * elapsed, n / elapsed]
