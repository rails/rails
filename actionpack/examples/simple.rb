$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../lib"
require 'action_controller'

class PeopleController < ActionController::Base
  def index
    head :ok
  end
end

status, headers, body = PeopleController.action(:index).call({ 'rack.input' => StringIO.new('') })

puts status
puts headers.to_yaml
puts '---'
body.each do |part|
  puts part
end
