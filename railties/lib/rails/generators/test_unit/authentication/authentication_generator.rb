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

      def create_mailer_preview_files
        template "test/mailers/previews/passwords_mailer_preview.rb" if defined?(ActionMailer::Railtie)
      end

      def create_test_helper_files
        template "test/test_helpers/session_test_helper.rb"
      end

      def configure_test_helper
        inject_into_file "test/test_helper.rb", "require_relative \"test_helpers/session_test_helper\"\n", after: "require \"rails/test_help\"\n"
      end
    end
  end
end
