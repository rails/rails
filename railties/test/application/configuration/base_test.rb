require 'isolation/abstract_unit'
require 'rack/test'
require 'env_helpers'

module ApplicationTests
  module ConfigurationTests
    class BaseTest < ActiveSupport::TestCase
      def setup
        build_app
        boot_rails
        FileUtils.rm_rf("#{app_path}/config/environments")
      end

      def teardown
        teardown_app
        FileUtils.rm_rf(new_app) if File.directory?(new_app)
      end

      private
        def new_app
          File.expand_path("#{app_path}/../new_app")
        end

        def copy_app
          FileUtils.cp_r(app_path, new_app)
        end

        def app
          @app ||= Rails.application
        end

        def require_environment
          require "#{app_path}/config/environment"  
        end
    end
  end
end