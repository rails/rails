require 'isolation/abstract_unit'
require 'rack/test'

module ApplicationTests
  class RoutingTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      build_app
      boot_rails
    end

    test "assets routes have higher priority" do
      app_file "app/assets/javascripts/demo.js.erb", "<%= :alert %>();"

      app_file 'config/routes.rb', <<-RUBY
        AppTemplate::Application.routes.draw do
          match '*path', :to => lambda { |env| [200, { "Content-Type" => "text/html" }, "Not an asset"] }
        end
      RUBY

      get "/assets/demo.js"
      assert_match "alert()", last_response.body
    end
  end
end
