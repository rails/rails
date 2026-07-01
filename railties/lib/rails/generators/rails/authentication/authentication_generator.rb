# frozen_string_literal: true

require "rails/generators/bundle_helper"
require "rails/generators/js_package_manager"

module Rails
  module Generators
    class AuthenticationGenerator < Base # :nodoc:
      include BundleHelper
      include JsPackageManager

      class_option :api, type: :boolean,
        desc: "Generate API-only controllers and models, with no view templates"

      class_option :password_based, type: :boolean, default: false,
        desc: "Generate password-based authentication instead of magic links"

      hook_for :template_engine, as: :authentication do |template_engine|
        invoke template_engine unless options.api?
      end

      def create_authentication_files
        @user_model_exists = File.exist?(File.expand_path("app/models/user.rb", destination_root))

        template "app/models/session.rb"
        template "app/models/user.rb"
        template "app/models/current.rb"

        template "app/controllers/sessions_controller.rb"
        template "app/controllers/concerns/authentication.rb"
        template "app/controllers/sessions/passkeys_controller.rb"
        template "app/controllers/my/passkeys_controller.rb"

        if options.password_based?
          template "app/controllers/passwords_controller.rb"
        else
          template "app/models/magic_link.rb"
          template "app/controllers/sessions/magic_links_controller.rb"
        end

        template "app/channels/application_cable/connection.rb" if defined?(ActionCable::Engine)

        if defined?(ActionMailer::Railtie)
          if options.password_based?
            template "app/mailers/passwords_mailer.rb"

            template "app/views/passwords_mailer/reset.html.erb"
            template "app/views/passwords_mailer/reset.text.erb"
          else
            template "app/mailers/magic_link_mailer.rb"

            template "app/views/magic_link_mailer/sign_in.html.erb"
            template "app/views/magic_link_mailer/sign_in.text.erb"
          end
        end
      end

      def configure_application_controller
        inject_into_class "app/controllers/application_controller.rb", "ApplicationController", "  include Authentication\n"
      end

      def configure_authentication_routes
        route <<~RUBY.strip
          namespace :my do
            resources :passkeys, except: %i[ show new ]
          end
        RUBY

        if options.password_based?
          route "resources :passwords, param: :token, only: [:new, :create, :edit, :update]"
          route <<~RUBY.strip
            resource :session, only: [:new, :create, :destroy] do
              resource :passkey, only: :create, module: :sessions
            end
          RUBY
        else
          route <<~RUBY.strip
            resource :session, only: [:new, :create, :destroy] do
              resource :magic_link, only: [:show, :create], module: :sessions
              resource :passkey, only: :create, module: :sessions
            end
          RUBY
        end
      end

      def add_passkey_javascript
        return if options.api?

        destination = Pathname(destination_root)

        if using_js_runtime?
          say "Installing JavaScript dependencies", :green
          run package_add_command("@rails/actionpack-passkeys")
        end

        if (application_javascript_path = destination.join("app/javascript/application.js")).exist?
          insert_into_file application_javascript_path.to_s, %(\nimport "@rails/actionpack-passkeys"\n)
        end

        if (importmap_path = destination.join("config/importmap.rb")).exist?
          append_to_file importmap_path.to_s, %(pin "@rails/actionpack-passkeys", to: "actionpack-passkeys.esm.js"\n)
        end
      end

      def add_gems
        if options.password_based?
          if File.read(File.expand_path("Gemfile", destination_root)).include?('gem "bcrypt"')
            uncomment_lines "Gemfile", /gem "bcrypt"/
            bundle_command("install --quiet")
          else
            bundle_command("add bcrypt", {}, quiet: true)
          end
        end
      end

      def preview_emails_in_development
        if !options.password_based? && defined?(ActionMailer::Railtie)
          bundle_command("add mailbin --group development", {}, quiet: true)

          environment <<~RUBY, env: "development"
            config.action_mailer.delivery_method = :mailbin
            config.action_mailer.perform_deliveries = true
          RUBY

          route "mount Mailbin::Engine => :mailbin if Rails.env.development?"
        end
      end

      def add_migrations
        if options.password_based?
          unless @user_model_exists
            generate "migration", "CreateUsers", "email_address:string!:uniq password_digest:string!", "--force"
          end
        else
          unless @user_model_exists
            generate "migration", "CreateUsers", "email_address:string!:uniq", "--force"
          end

          generate "migration", "CreateMagicLinks", "user:references code:string!:uniq expires_at:datetime!", "--force"
        end

        generate "migration", "CreateSessions", "user:references ip_address:string user_agent:string", "--force"

        rails_command "railties:install:migrations FROM=action_pack_passkey", inline: true
      end

      hook_for :test_framework
    end
  end
end
