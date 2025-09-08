# frozen_string_literal: true

require "rails/generators/test_unit"

module TestUnit # :nodoc:
  module Generators # :nodoc:
    class AuthenticationGenerator < Rails::Generators::Base # :nodoc:
      def create_user_test_files
        template "test/fixtures/users.yml"
        template "test/models/user_test.rb"
      end

      def create_mailer_preview_files
        template "test/mailers/previews/passwords_mailer_preview.rb" if defined?(ActionMailer::Railtie)
      end
    end
  end
end
