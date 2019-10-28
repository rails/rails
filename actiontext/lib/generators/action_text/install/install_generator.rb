# frozen_string_literal: true

require "pathname"
require "json"

module ActionText
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def install_javascript_dependencies
        run "rake app:update:bin"

        say "Installing JavaScript dependencies"
        run "yarn add #{js_dependencies.map { |name, version| "#{name}@#{version}" }.join(" ")}",
          abort_on_failure: true, capture: true
      end

      def append_dependencies_to_package_file
        app_javascript_pack_path = Pathname.new("app/javascript/packs/application.js")

        if app_javascript_pack_path.exist?
          js_dependencies.keys.each do |name|
            line = %[require("#{name}")]

            unless app_javascript_pack_path.read.include? line
              say "Adding #{name} to #{app_javascript_pack_path}"
              append_to_file app_javascript_pack_path, "\n#{line}"
            end
          end
        else
          warn <<~WARNING
            WARNING: Action Text can't locate your JavaScript bundle to add its package dependencies.

            Add these lines to any bundles:

            require("trix")
            require("@rails/actiontext")

            Alternatively, install and setup the webpacker gem then rerun `bin/rails action_text:install`
            to have these dependencies added automatically.
          WARNING
        end
      end

      def create_actiontext_files
        template "actiontext.scss", "app/assets/stylesheets/actiontext.scss"

        copy_file "#{GEM_ROOT}/app/views/active_storage/blobs/_blob.html.erb",
                  "app/views/active_storage/blobs/_blob.html.erb"
      end

      def create_migrations
        run "rake active_storage:install:migrations"
        run "rake railties:install:migrations"
        run "rake action_text:install:migrations"
      end

      hook_for :test_framework

      private
        GEM_ROOT = "#{__dir__}/../../../.."

        def js_dependencies
          package_contents = File.read(Pathname.new("#{GEM_ROOT}/package.json"))
          js_package = JSON.load(package_contents)

          js_package["peerDependencies"].dup.merge \
            js_package["name"] => "^#{js_package["version"]}"
        end
    end
  end
end
