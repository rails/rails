# frozen_string_literal: true

require "rails/generators/bundle_helper"

module Rails
  module Generators
    class AuthenticationGenerator < Base # :nodoc:
      include BundleHelper

      class_option :api, type: :boolean,
        desc: "Generate API-only controllers and models, with no view templates"

      hook_for :template_engine, as: :authentication do |template_engine|
        invoke template_engine unless options.api?
      end

      def create_authentication_files
        template "app/models/session.rb"
        template "app/models/user.rb"
        template "app/models/current.rb"

        template "app/controllers/sessions_controller.rb"
        template "app/controllers/concerns/authentication.rb"
        template "app/controllers/passwords_controller.rb"

        template "app/channels/application_cable/connection.rb" if defined?(ActionCable::Engine)

        if defined?(ActionMailer::Railtie)
          template "app/mailers/passwords_mailer.rb"

          template "app/views/passwords_mailer/reset.html.erb"
          template "app/views/passwords_mailer/reset.text.erb"

          template "test/mailers/previews/passwords_mailer_preview.rb"
        end

        template "test/test_helpers/session_test_helper.rb"
      end

      def configure_application_controller
        inject_into_class "app/controllers/application_controller.rb", "ApplicationController", "  include Authentication\n"
      end

      def configure_authentication_routes
        route "resources :passwords, param: :token"
        route "resource :session"
      end

      def enable_bcrypt
        if File.read(File.expand_path("Gemfile", destination_root)).include?('gem "bcrypt"')
          uncomment_lines "Gemfile", /gem "bcrypt"/
          bundle_command("install --quiet")
        else
          bundle_command("add bcrypt", {}, quiet: true)
        end
      end

      def add_migrations
        generate "migration", "CreateUsers", "email_address:string!:uniq password_digest:string!", "--force"
        generate "migration", "CreateSessions", "user:references ip_address:string user_agent:string", "--force"
      end

      def configure_test_helper
        inject_into_file "test/test_helper.rb", "require_relative \"test_helpers/session_test_helper\"\n", after: "require \"rails/test_help\"\n"
        inject_into_class "test/test_helper.rb", "TestCase", "    include SessionTestHelper\n"
      end

      hook_for :test_framework
    end
  end
end
