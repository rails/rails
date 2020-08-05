# frozen_string_literal: true

require "pathname"
require "json"

module ActionText
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def install_javascript_dependencies
        rails_command "app:binstub:yarn", inline: true

        say "Installing JavaScript dependencies", :green
        run "bin/yarn add #{js_dependencies.map { |name, version| "#{name}@#{version}" }.join(" ")}",
          abort_on_failure: true, capture: true
      end

      def append_dependencies_to_package_file
        if (app_javascript_pack_path = Pathname.new("app/javascript/packs/application.js")).exist?
          js_dependencies.each_key do |dependency|
            line = %[require("#{dependency}")]

            unless app_javascript_pack_path.read.include? line
              say "Adding #{dependency} to #{app_javascript_pack_path}", :green
              append_to_file app_javascript_pack_path, "\n#{line}"
            end
          end
        else
          say <<~WARNING, :red
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
        rails_command "railties:install:migrations FROM=active_storage,action_text", inline: true
      end

      hook_for :test_framework

      private
        GEM_ROOT = "#{__dir__}/../../../.."

        def js_dependencies
          js_package = JSON.load(Pathname.new("#{GEM_ROOT}/package.json"))
          js_package["peerDependencies"].merge \
            js_package["name"] => "^#{js_package["version"]}"
        end
    end
  end
end
