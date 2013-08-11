require 'isolation/abstract_unit'
require 'rack/test'

module ApplicationTests
  class BasicRenderingTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      build_app
    end

    def teardown
      teardown_app
    end

    test "Rendering without ActionView" do
      gsub_app_file 'config/application.rb', "require 'rails/all'", <<-RUBY
        require "active_model/railtie"
        require "action_controller/railtie"
      RUBY

      # Turn off ActionView and jquery-rails (it depends on AV)
      $:.reject! {|path| path =~ /(actionview|jquery\-rails)/ }
      boot_rails

      app_file 'app/controllers/pages_controller.rb', <<-RUBY
        class PagesController < ApplicationController
          def render_hello_world
            render text: "Hello World!"
          end

          def render_nothing
            render nothing: true
          end

          def no_render; end

          def raise_error
            render foo: "bar"
          end
        end
      RUBY

      get '/pages/render_hello_world'
      assert_equal 200, last_response.status
      assert_equal "Hello World!", last_response.body
      assert_equal "text/plain; charset=utf-8", last_response.content_type

      get '/pages/render_nothing'
      assert_equal 200, last_response.status
      assert_equal " ", last_response.body
      assert_equal "text/plain; charset=utf-8", last_response.content_type

      get '/pages/no_render'
      assert_equal 500, last_response.status

      get '/pages/raise_error'
      assert_equal 500, last_response.status
    end
  end
end
