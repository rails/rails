# frozen_string_literal: true

# :markup: markdown

require "pathname"
require "json"
require "rails/generators/js_package_manager"

module ActionText
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      include Rails::Generators::PackageManager

      source_root File.expand_path("templates", __dir__)

      class_option :editor, type: :string, default: "trix"

      def install_editor
        return unless using_js_runtime?

        editor = options[:editor]

        say "Installing #{editor} JavaScript dependency", :green
        run package_add_command(editor)
      end

      def append_editor
        destination = Pathname(destination_root)
        editor = options[:editor]

        if (application_javascript_path = destination.join("app/javascript/application.js")).exist?
          insert_into_file application_javascript_path.to_s, %(\nimport "#{editor}"\n)
        else
          say <<~INSTRUCTIONS, :green
            You must import the #{editor} JavaScript module in your application entrypoint.
          INSTRUCTIONS
        end

        if (importmap_path = destination.join("config/importmap.rb")).exist?
          append_to_file importmap_path.to_s, %(pin "#{editor}"\n)
        end
      end

      def install_javascript_dependencies
        return unless using_js_runtime?

        say "Installing JavaScript dependencies", :green
        run package_add_command("@rails/actiontext")
      end

      def append_javascript_dependencies
        destination = Pathname(destination_root)

        if (application_javascript_path = destination.join("app/javascript/application.js")).exist?
          insert_into_file application_javascript_path.to_s, %(\nimport "@rails/actiontext"\n)
        else
          say <<~INSTRUCTIONS, :green
            You must import the @rails/actiontext JavaScript module in your application entrypoint.
          INSTRUCTIONS
        end

        if (importmap_path = destination.join("config/importmap.rb")).exist?
          append_to_file importmap_path.to_s, %(pin "@rails/actiontext", to: "actiontext.esm.js"\n)
        end
      end

      def create_actiontext_files
        template "actiontext.css", "app/assets/stylesheets/actiontext.css"

        gem_root = "#{__dir__}/../../../.."

        copy_file "#{gem_root}/app/views/active_storage/blobs/_blob.html.erb",
          "app/views/active_storage/blobs/_blob.html.erb"

        copy_file "#{gem_root}/app/views/layouts/action_text/contents/_content.html.erb",
          "app/views/layouts/action_text/contents/_content.html.erb"
      end

      def create_migrations
        rails_command "railties:install:migrations FROM=active_storage,action_text", inline: true
      end

      hook_for :test_framework
    end
  end
end
