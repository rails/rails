# frozen_string_literal: true

module Rails
  module Generators
    class ChannelGenerator < NamedBase
      source_root File.expand_path("templates", __dir__)

      argument :actions, type: :array, default: [], banner: "method method"

      class_option :assets, type: :boolean

      check_class_collision suffix: "Channel"

      hook_for :test_framework

      def install_javascript_dependencies
        if using_node = Pathname(destination_root).join("package.json").exist?
          say "Installing JavaScript dependencies", :green
          run "yarn add @rails/actioncable"
        end
      end

      def create_channel_file
        template "channel.rb", File.join("app/channels", class_path, "#{file_name}_channel.rb")
        destination = Pathname(destination_root)

        if options[:assets] && destination.join("app/javascript").exist?
          using_node      = destination.join("package.json").exist?
          using_importmap = destination.join("config/importmap.rb").exist?

          # Setup for all channels
          if first_setup_required = !destination.join("app/javascript/channels/index.js").exist?
            template "javascript/index.js", "app/javascript/channels/index.js"
            template "javascript/consumer.js", "app/javascript/channels/consumer.js"
            append_to_file "app/javascript/application.js",
              using_node ? %(import "./channels"\n) : %(import "channels"\n)

            if using_importmap
              append_to_file "config/importmap.rb", <<-RUBY
 pin "@rails/actioncable", to: "actioncable.esm.js"
 pin_all_from "app/javascript/channels", under: "channels"
              RUBY
            end
          end

          # New individual channel
          channel_js_path = File.join("app/javascript/channels", class_path, "#{file_name}_channel")
          js_template "javascript/channel", channel_js_path
          gsub_file "#{channel_js_path}.js", /\.\/consumer/, "channels/consumer" unless using_node

          append_to_file "app/javascript/channels/index.js",
            using_node ? %(import ",/#{file_name}_channel"\n) : %(import "channels/#{file_name}_channel"\n)
        end

        generate_application_cable_files
      end

      private
        def file_name
          @_file_name ||= super.sub(/_channel\z/i, "")
        end

        # FIXME: Change these files to symlinks once RubyGems 2.5.0 is required.
        def generate_application_cable_files
          return if behavior != :invoke

          files = [
            "application_cable/channel.rb",
            "application_cable/connection.rb"
          ]

          files.each do |name|
            path = File.join("app/channels/", name)
            template(name, path) if !File.exist?(path)
          end
        end
    end
  end
end
