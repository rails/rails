# frozen_string_literal: true

require "rails/generators/test_unit"

module TestUnit # :nodoc:
  module Generators # :nodoc:
    class AuthenticationGenerator < Rails::Generators::Base # :nodoc:
      class_option :password_based, type: :boolean, default: false

      def create_user_test_files
        template "test/fixtures/users.yml"
        template "test/models/user_test.rb"
      end

      def create_controller_test_files
        template "test/controllers/sessions_controller_test.rb"
        template "test/controllers/sessions/passkeys_controller_test.rb"

        if options.password_based?
          template "test/controllers/passwords_controller_test.rb"
        else
          template "test/controllers/sessions/magic_links_controller_test.rb"
        end
      end

      def create_mailer_preview_files
        if defined?(ActionMailer::Railtie)
          if options.password_based?
            template "test/mailers/previews/passwords_mailer_preview.rb"
          else
            template "test/mailers/previews/magic_link_mailer_preview.rb"
          end
        end
      end

      def create_test_helper_files
        template "test/test_helpers/session_test_helper.rb"
        template "test/test_helpers/webauthn_test_helper.rb"
      end

      def configure_test_helper
        inject_into_file "test/test_helper.rb", "require_relative \"test_helpers/session_test_helper\"\n", after: "require \"rails/test_help\"\n"
      end
    end
  end
end
