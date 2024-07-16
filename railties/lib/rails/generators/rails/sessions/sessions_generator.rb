# frozen_string_literal: true

module Rails
  module Generators
    class SessionsGenerator < Base # :nodoc:
      def create_session_files
        template "models/session.rb", File.join("app/models/session.rb")
        template "models/user.rb", File.join("app/models/user.rb")
        template "models/current.rb", File.join("app/models/current.rb")

        template "controllers/sessions_controller.rb", File.join("app/controllers/sessions_controller.rb")
        template "controllers/concerns/authentication.rb", File.join("app/controllers/concerns/authentication.rb")

        template "views/sessions/new.html.erb", File.join("app/views/sessions/new.html.erb")
      end

      def configure_application
        gsub_file "app/controllers/application_controller.rb", /(class ApplicationController < ActionController::Base)/, "\\1\n  include Authentication"
        route "resource :session"
      end

      def enable_bcrypt
        if File.read("Gemfile").include?('gem "bcrypt"')
          uncomment_lines "Gemfile", /gem "bcrypt"/
          Bundler.with_original_env { execute_command :bundle, "" }
        else
          Bundler.with_original_env { execute_command :bundle, "add bcrypt" }
        end
      end

      def add_migrations
        generate "migration CreateUsers email_address:string!:uniq password_digest:string! --force"
        generate "migration CreateSessions user:references token:token ip_address:string user_agent:string --force"
      end
    end
  end
end
