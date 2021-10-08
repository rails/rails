# frozen_string_literal: true

require "active_record/connection_configurations/connection_config"

module ActiveRecord
  class ConnectionConfigurations # :nodoc:
    include Enumerable

    attr_reader :configurations

    def initialize(configurations)
      @configurations = build_configs(configurations)
    end

    def each
      configurations.each do |class_name, configuration|
        yield [class_name, configuration]
      end
    end

    def configs_for(class_name:)
      configurations[class_name]
    end

    private
      def build_configs(configurations)
        result = {}

        configurations.each do |class_name, config|
          result[class_name] = ConnectionConfig.new(config)
        end

        result
      end
  end
end
