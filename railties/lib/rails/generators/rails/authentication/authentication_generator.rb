# frozen_string_literal: true

module Rails
  module Generators
    class AuthenticationGenerator < Base # :nodoc:
      class_option :api, type: :boolean,
        desc: "Generate API-only controllers and models, with no view templates"
      class_option :token, type: :boolean,
        desc: "Generate authentication tokens instead of setting cookies"

      hook_for :template_engine, as: :authentication do |template_engine|
        invoke template_engine unless options.api?
      end

      def create_authentication_files
        template "app/models/session.rb"
        template "app/models/user.rb"
        template "app/models/current.rb"

        template "app/controllers/sessions_controller.rb"

        template "app/controllers/passwords_controller.rb"

        template "app/mailers/passwords_mailer.rb"

        template "app/views/passwords_mailer/reset.html.erb"
        template "app/views/passwords_mailer/reset.text.erb"

        template "test/mailers/previews/passwords_mailer_preview.rb"

        template_considering_options
      end

      def template_considering_options
        if options.token?
          template "app/controllers/concerns/token/authentication.rb"
          template "app/controllers/concerns/token/sessions_controller.rb"
          template "app/channels/application_cable/token/connection.rb" if defined?(ActionCable::Engine)


        else
          template "app/controllers/concerns/default/authentication.rb"
          template "app/controllers/concerns/default/sessions_controller.rb"
          template "app/channels/application_cable/default/connection.rb" if defined?(ActionCable::Engine)

        end
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
          Bundler.with_original_env { execute_command :bundle, "install --quiet" }
        else
          Bundler.with_original_env { execute_command :bundle, "add bcrypt", capture: true }
        end
      end

      def add_migrations
        generate "migration", "CreateUsers", "email_address:string!:uniq password_digest:string!", "--force"
        generate "migration", "CreateSessions", "user:references ip_address:string user_agent:string", "--force"
      end

      hook_for :test_framework
    end
  end
end
