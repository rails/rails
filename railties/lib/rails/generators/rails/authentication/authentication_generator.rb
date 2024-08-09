# frozen_string_literal: true

module Rails
  module Generators
    class AuthenticationGenerator < Base # :nodoc:
      class_option :api, type: :boolean,
        desc: "Generate API-only controllers and models, with no view templates"

      hook_for :template_engine, as: :authentication do |template_engine|
        invoke template_engine unless options.api?
      end

      def create_authentication_files
        template "models/session.rb", File.join("app/models/session.rb")
        template "models/user.rb", File.join("app/models/user.rb")
        template "models/current.rb", File.join("app/models/current.rb")

        template "controllers/sessions_controller.rb", File.join("app/controllers/sessions_controller.rb")
        template "controllers/concerns/authentication.rb", File.join("app/controllers/concerns/authentication.rb")
        template "controllers/passwords_controller.rb", File.join("app/controllers/passwords_controller.rb")

        template "mailers/passwords_mailer.rb", File.join("app/mailers/passwords_mailer.rb")

        template "views/passwords_mailer/reset.html.erb", File.join("app/views/passwords_mailer/reset.html.erb")
        template "views/passwords_mailer/reset.text.erb", File.join("app/views/passwords_mailer/reset.text.erb")

        template "test/mailers/previews/passwords_mailer_preview.rb", File.join("test/mailers/previews/passwords_mailer_preview.rb")
      end

      def configure_application_controller
        gsub_file "app/controllers/application_controller.rb", /(class ApplicationController < ActionController::Base)/, "\\1\n  include Authentication"
      end

      def configure_authentication_routes
        route "resources :passwords, param: :token"
        route "resource :session"
      end

      def enable_bcrypt
        if File.read("Gemfile").include?('gem "bcrypt"')
          uncomment_lines "Gemfile", /gem "bcrypt"/
          Bundler.with_original_env { execute_command :bundle, "install --quiet" }
        else
          Bundler.with_original_env { execute_command :bundle, "add bcrypt --quiet" }
        end
      end

      def add_migrations
        generate "migration CreateUsers email_address:string!:uniq password_digest:string! --force"
        generate "migration CreateSessions user:references ip_address:string user_agent:string --force"
      end
    end
  end
end
