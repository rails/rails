require 'abstract_unit'

module ActionDispatch
  module Routing
    class HelperTest < ActiveSupport::TestCase
      class Duck
        def to_param
          nil
        end
      end

      class Dog
        def to_param
          15
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
        assert_raises ActionController::UrlGenerationError do
          x.new.pond_duck_path Duck.new
        end
      end

      def test_do_not_fail_on_numeric
        rs = ::ActionDispatch::Routing::RouteSet.new
        rs.draw do
          resources :dogs
        end

        x = Class.new {
          include rs.url_helpers
        }
        assert_equal '/dogs/15/edit', x.new.edit_dog_path(Dog.new)
      end
    end
  end
end
