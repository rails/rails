require 'isolation/abstract_unit'
require 'open-uri'

class ServerTest < Test::Unit::TestCase
  include ActiveSupport::Testing::Isolation  

  def setup
    build_app
  end

  def test_app_should_run
    start_server
  end

  def test_app_should_run_in_a_rack_urlmap
    urlmap_config_ru = <<-EOF
    require ::File.expand_path('../config/environment',  __FILE__)
    run Rack::URLMap.new "/" => AppTemplate::Application
    EOF

    File.open("#{app_path}/config.ru", 'w') {|f| f.write(urlmap_config_ru) }

    start_server
  end
  
  def start_server
    Dir.chdir(app_path)

    require "#{rails_root}/config/environment"

    require 'rails/commands/server'

    server = Rails::Server.new

    t = Thread.new { server.start }
    until t.status == 'sleep'; t.join(0.5) end
    body = open("http://0.0.0.0:3000/") { |f| f.read }
    assert body.match(/Welcome aboard/)

    Process.kill(:INT, $$)
    t.join
  end
end