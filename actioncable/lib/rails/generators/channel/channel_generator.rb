# frozen_string_literal: true

module Rails
  module Generators
    class ChannelGenerator < NamedBase
      source_root File.expand_path("templates", __dir__)

      argument :actions, type: :array, default: [], banner: "method method"

      class_option :assets, type: :boolean

      check_class_collision suffix: "Channel"

      hook_for :test_framework

      def create_channel_file
        template "channel.rb", File.join("app/channels", class_path, "#{file_name}_channel.rb")

        if options[:assets]
          if behavior == :invoke
            if defined?(Webpacker::Engine)
              template "javascript/index.js", "#{Webpacker.config.source_path}/channels/index.js"
              template "javascript/consumer.js", "#{Webpacker.config.source_path}/channels/consumer.js"
            else
              template "javascript/consumer.js", "app/javascript/channels/consumer.js"
            end
          end

          if defined?(Webpacker::Engine)
            js_template "javascript/channel", File.join(Webpacker.config.source_path, "channels", class_path, "#{file_name}_channel")
          else
            channel_js_path = File.join("app/javascript/channels", class_path, "#{file_name}_channel")
            js_template "javascript/channel", channel_js_path
            gsub_file "#{channel_js_path}.js", /\.\/consumer/, "channels/consumer"

            append_to_file "app/javascript/application.js", %(\nimport "channels/#{file_name}_channel"\n)
          end
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
