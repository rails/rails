# frozen_string_literal: true

module Rails
  module Generators
    class ChannelGenerator < NamedBase
      source_root File.expand_path("templates", __dir__)

      argument :actions, type: :array, default: [], banner: "method method"

      class_option :assets, type: :boolean

      check_class_collision suffix: "Channel"

      hook_for :test_framework

      def create_channel_files
        create_shared_channel_files
        create_channel_file

        if using_javascript?
          if first_setup_required?
            create_shared_channel_javascript_files
            import_channels_in_javascript_entrypoint

            if using_importmap?
              pin_javascript_dependencies
            elsif using_node?
              install_javascript_dependencies
            end
          end

          create_channel_javascript_file
          import_channel_in_javascript_entrypoint
        end
      end

      private
        def create_shared_channel_files
          return if behavior != :invoke

          copy_file "#{__dir__}/templates/application_cable/channel.rb",
            "app/channels/application_cable/channel.rb"
          copy_file "#{__dir__}/templates/application_cable/connection.rb",
            "app/channels/application_cable/connection.rb"
        end

        def create_channel_file
          template "channel.rb",
            File.join("app/channels", class_path, "#{file_name}_channel.rb")
        end

        def create_shared_channel_javascript_files
          template "javascript/index.js", "app/javascript/channels/index.js"
          template "javascript/consumer.js", "app/javascript/channels/consumer.js"
        end

        def create_channel_javascript_file
          channel_js_path = File.join("app/javascript/channels", class_path, "#{file_name}_channel")
          js_template "javascript/channel", channel_js_path
          gsub_file "#{channel_js_path}.js", /\.\/consumer/, "channels/consumer" unless using_node?
        end

        def import_channels_in_javascript_entrypoint
          append_to_file "app/javascript/application.js",
            using_node? ? %(import "./channels"\n) : %(import "channels"\n)
        end

        def import_channel_in_javascript_entrypoint
          append_to_file "app/javascript/channels/index.js",
            using_node? ? %(import "./#{file_name}_channel"\n) : %(import "channels/#{file_name}_channel"\n)
        end

        def install_javascript_dependencies
          say "Installing JavaScript dependencies", :green
          run "yarn add @rails/actioncable"
        end

        def pin_javascript_dependencies
          append_to_file "config/importmap.rb", <<-RUBY
pin "@rails/actioncable", to: "actioncable.esm.js"
pin_all_from "app/javascript/channels", under: "channels"
          RUBY
        end


        def file_name
          @_file_name ||= super.sub(/_channel\z/i, "")
        end

        def first_setup_required?
          !root.join("app/javascript/channels/index.js").exist?
        end

        def using_javascript?
          @using_javascript ||= options[:assets] && root.join("app/javascript").exist?
        end

        def using_node?
          @using_node ||= root.join("package.json").exist?
        end

        def using_importmap?
          @using_importmap ||= root.join("config/importmap.rb").exist?
        end

        def root
          @root ||= Pathname(destination_root)
        end
    end
  end
end
