require 'abstract_unit'

module ActionDispatch
  module Routing
    class HelperTest < ActiveSupport::TestCase
      class Duck
        def to_param
          nil
        end
      end

      def test_exception
        rs = ::ActionDispatch::Routing::RouteSet.new
        rs.draw do
          resources :ducks do
            member do
              get :pond
            end
          end
        end

        x = Class.new {
          include rs.url_helpers
        }
        assert_raises ActionController::RoutingError do
          x.new.pond_duck_path Duck.new
        end
      end
    end
  end
end
