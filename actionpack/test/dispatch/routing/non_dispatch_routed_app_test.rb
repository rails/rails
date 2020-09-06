# frozen_string_literal: true

require 'abstract_unit'

module ActionDispatch
  module Routing
    class NonDispatchRoutedAppTest < ActionDispatch::IntegrationTest
      # For example, Grape::API
      class SimpleApp
        def self.call(env)
          [ 200, { 'Content-Type' => 'text/plain' }, [] ]
        end

        def self.routes
          []
        end
      end

      setup { @app = SimpleApp }

      test 'does not except' do
        get '/foo'
        assert_response :success
      end
    end
  end
end
