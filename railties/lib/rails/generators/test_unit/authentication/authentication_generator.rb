# frozen_string_literal: true

require "rails/generators/test_unit"

module TestUnit # :nodoc:
  module Generators # :nodoc:
    class AuthenticationGenerator < Rails::Generators::Base # :nodoc:
      def create_user_test_files
        template "test/fixtures/users.yml"
        template "test/models/user_test.rb"
      end

      def create_controller_test_files
        template "test/controllers/sessions_controller_test.rb"
        template "test/controllers/passwords_controller_test.rb"
      end

      def ensure_root_route
        in_root do
          if !File.read("config/routes.rb").match?(/^ *root /)
            route 'root "fill-me"'
          end
        end
      end
    end
  end
end
