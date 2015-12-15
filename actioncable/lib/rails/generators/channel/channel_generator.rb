module Rails
  module Generators
    class ChannelGenerator < NamedBase
      source_root File.expand_path("../templates", __FILE__)

      argument :actions, type: :array, default: [], banner: "method method"

      check_class_collision suffix: "Channel"

      def create_channel_file
        template "channel.rb", File.join('app/channels', class_path, "#{file_name}_channel.rb")
        template "assets/channel.coffee", File.join('app/assets/javascripts/cable/channels', class_path, "#{file_name}.coffee")

        if self.behavior == :invoke
          template "application_cable/connection.rb", 'app/channels/application_cable/connection.rb'
          template "application_cable/channel.rb", 'app/channels/application_cable/channel.rb'
          template "assets/consumer.coffee", 'app/assets/javascripts/cable/index.coffee'
        end
      end

      protected
        def file_name
          @_file_name ||= super.gsub(/\_channel/i, '')
        end
    end
  end
end
