# frozen_string_literal: true

require "pathname"
require "json"

module ActionText
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def install_javascript_dependencies
        if using_node = Rails.root.join("package.json").exist?
          say "Installing JavaScript dependencies", :green
          yarn_command "add @rails/activestorage"
        end
      end

      def append_javascript_dependencies
        if (application_javascript_path = Rails.root.join("app/javascript/application.js")).exist?
          insert_into_file application_javascript_path.to_s, %(import "trix"\nimport "@rails/actiontext"\n)
        else
          say <<~INSTRUCTIONS, :green
            You must import the @rails/actiontext and trix JavaScript modules in your application entrypoint.
          INSTRUCTIONS
        end

        if (importmap_path = Rails.root.join("config/importmap.rb")).exist?
          append_to_file importmap_path.to_s, %(pin "trix"\npin "@rails/actiontext", to: "actiontext.js"\n)
        end
      end

      def create_actiontext_files
        template "actiontext.css", "app/assets/stylesheets/actiontext.css"

        copy_file "#{GEM_ROOT}/app/views/active_storage/blobs/_blob.html.erb",
          "app/views/active_storage/blobs/_blob.html.erb"

        copy_file "#{GEM_ROOT}/app/views/layouts/action_text/contents/_content.html.erb",
          "app/views/layouts/action_text/contents/_content.html.erb"
      end

      def enable_image_processing_gem
        if (gemfile_path = Rails.root.join("Gemfile")).exist?
          say "Ensure image_processing gem has been enabled so image uploads will work (remember to bundle!)"
          uncomment_lines gemfile_path, /gem "image_processing"/
        end
      end

      def create_migrations
        rails_command "railties:install:migrations FROM=active_storage,action_text", inline: true
      end

      hook_for :test_framework

      private
        GEM_ROOT = "#{__dir__}/../../../.."

        def yarn_command(command, config = {})
          in_root { run "#{Thor::Util.ruby_command} bin/yarn #{command}", abort_on_failure: true, **config }
        end
    end
  end
end
