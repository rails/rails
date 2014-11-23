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
        assert_raises ActionController::UrlGenerationError do
          x.new.pond_duck_path Duck.new
        end
      end

      def test_path_deprecation
        rs = ::ActionDispatch::Routing::RouteSet.new
        rs.draw do
          resources :ducks
        end

        x = Class.new {
          include rs.url_helpers(false)
        }
        assert_deprecated do
          assert_equal '/ducks', x.new.ducks_path
        end
      end


      def test_relative_url_root_is_respected_with_locale
        orig_setup = ENV['RAILS_RELATIVE_URL_ROOT']
        ENV['RAILS_RELATIVE_URL_ROOT'] = "moshe"

        rs = ::ActionDispatch::Routing::RouteSet.new
        rs.draw do
          scope '/:locale', shallow_path: "/:locale", locale: /en|he/ do
            resources :drongos
          end
        end

        x = Class.new {
          include rs.url_helpers
        }

        assert_equal 'moshe/he/drongos', x.new.drongos_path(locale: 'he')

        ENV['RAILS_RELATIVE_URL_ROOT'] = orig_setup
      end

      def test_relative_url_root_is_respected_via_helper
        orig_setup = ENV['RAILS_RELATIVE_URL_ROOT']
        ENV['RAILS_RELATIVE_URL_ROOT'] = "moshe"

        rs = ::ActionDispatch::Routing::RouteSet.new
        rs.draw do
          resources :drongos
        end

        x = Class.new {
          include rs.url_helpers
        }

        assert_equal 'moshe/drongos', x.new.drongos_path

        ENV['RAILS_RELATIVE_URL_ROOT'] = orig_setup
      end

    end
  end
end
