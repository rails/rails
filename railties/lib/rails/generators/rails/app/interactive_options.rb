# frozen_string_literal: true

module Rails
  module Generators
    class InteractiveOptions # :nodoc:
      include Database
      include Thor::Shell

      attr_reader :options

      def self.perform(initial_options)
        new(initial_options).perform
      end

      def initialize(initial_options)
        @options = initial_options
      end

      def perform
        say "Rails CLI #{Rails.version}", :green

        case inquire_rails_version
        when "dev"    then options[:dev] = true
        when "edge"   then options[:edge] = true
        when "main" then options[:main] = true
        end

        options[:database]             = inquire_database
        options[:skip_action_cable]    = inquire_action_cable
        options[:skip_action_mailer]   = inquire_action_mailer
        options[:skip_action_mailbox]  = inquire_action_mailbox
        options[:skip_active_storage]  = inquire_active_storage
        options[:skip_action_text]     = inquire_action_text
        options[:skip_bootsnap]        = inquire_bootsnap
        options[:skip_jbuilder]        = inquire_jbuilder
        options[:skip_javascript]      = inquire_javascript
        options[:skip_spring]          = inquire_spring
        options[:skip_sprockets]       = inquire_sprockets
        options[:skip_system_tests]    = inquire_system_tests
        options[:skip_turbolinks]      = inquire_turbolinks
        options[:skip_webpack_install] = inquire_webpack
        options[:webpack]              = inquire_webpack_library unless options[:skip_webpack_install]

        options
      end

      private
        def inquire_rails_version
          say <<~MESSAGE
          Target different versions of rails for your application.
          *dev* will target your checked out version of rails.
          *edge* will target the latest commit on rails.
          *main* will target the rails main branch.
          *stable* will target the rails gem version you have installed.
          MESSAGE
          inquire_from_list("What is your preferred rails version?", %w(dev edge main stable), "stable")
        end

        def inquire_database
          inquire_from_list("What is your preferred database?", DATABASES, options[:database])
        end

        def inquire_action_cable
          say "Action cable integrates web sockets with your rails application: https://guides.rubyonrails.org/action_cable_overview.html"
          inquire_boolean("Skip action cable?", options[:skip_action_cable])
        end

        def inquire_action_mailer
          say "Action mailer is a framework for designing email services: https://guides.rubyonrails.org/action_mailer_basics.html"
          inquire_boolean("Skip action mailer?", options[:skip_action_mailer])
        end

        def inquire_action_mailbox
          say "Action Mailbox routes incoming emails to controller-like mailboxes for processing in Rails: https://guides.rubyonrails.org/action_mailbox_basics.html"
          inquire_boolean("Skip action mailbox?", options[:skip_action_mailbox])
        end

        def inquire_active_storage
          say "Active Storage makes it simple to upload and reference files in cloud services: https://guides.rubyonrails.org/active_storage_overview.html"
          inquire_boolean("Skip active storage?", options[:skip_active_storage])
        end

        def inquire_action_text
          say "Action Text brings rich text content and editing to Rails: https://guides.rubyonrails.org/action_text_overview.html"
          inquire_boolean("Skip action text?", options[:skip_action_text])
        end

        def inquire_bootsnap
          say "Bootsnap makes Rails application boot faster: https://github.com/Shopify/bootsnap"
          inquire_boolean("Skip bootsnap?", options[:skip_bootsnap])
        end

        def inquire_jbuilder
          say "Jbuilder generates JSON objects with a Builder-style DSL: https://github.com/rails/jbuilder"
          inquire_boolean("Skip jbuilder?", options[:skip_jbuilder])
        end

        def inquire_javascript
          say "Use yarn to handle your package dependency management."
          inquire_boolean("Skip javascript?", options[:skip_javascript])
        end

        def inquire_spring
          say "Rails application preloader, speeds up development by keeping your application running in the background: https://github.com/rails/spring"
          inquire_boolean("Skip spring?", options[:skip_spring])
        end

        def inquire_sprockets
          say "Sprockets is a Ruby library for compiling and serving web assets: https://github.com/rails/sprockets"
          inquire_boolean("Skip sprocket?", options[:skip_sprockets])
        end

        def inquire_system_tests
          say "System tests are useful for writing end-to-end tests with a tool like capybara."
          inquire_boolean("Skip system tests?", options[:skip_system_tests])
        end

        def inquire_turbolinks
          say "Turbolinks makes navigating your web application faster: https://github.com/turbolinks/turbolinks"
          inquire_boolean("Skip turbolinks?", options[:skip_turbolinks])
        end

        def inquire_webpack
          say "Webpacker manages your app-like JavaScript modules in Rails: https://github.com/rails/webpacker"
          inquire_boolean("Skip webpack?", options[:skip_webpack_install])
        end

        def inquire_webpack_library
          inquire_from_list("What is your preferred webpack library?", AppGenerator::WEBPACKS, options[:webpack])
        end

        # Ask a boolean question. Returns true for "y" and false for "n".
        def inquire_boolean(question, default = true)
          answer = inquire_from_list question, %w(y n), default ? "y" : "n"
          answer == "y" ? true : false
        end

        # Ask a question from a preset list of answers. Returns one of the preset answers.
        def inquire_from_list(question, possible_answers, default = nil)
          ask question, limited_to: possible_answers, default: default
        end
    end
  end
end
