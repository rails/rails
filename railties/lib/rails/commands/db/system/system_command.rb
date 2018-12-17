# frozen_string_literal: true

require "rails/command/environment_argument"

module Rails
  module Db
    class System # :nodoc:
      attr_reader :environment

      def initialize(options = {})
        @environment = options.fetch("environment", rails_env)
      end

      def to_s
        if configurations.one?
          configurations.first.adapter
        else
          configurations.map do |config|
            [config.spec_name, config.adapter].join(" => ")
          end.join("\n")
        end
      end

      private
        def rails_env
          Rails.try(:env)&.to_s || ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"
        end

        def configurations
          @configurations ||= ActiveRecord::Base.configurations.configs_for(
            env_name: @environment
          )
        end
    end
  end

  module Command
    module Db
      class SystemCommand < Base # :nodoc:
        include EnvironmentArgument

        def perform
          extract_environment_option_from_argument

          require_application_and_environment!
          say Rails::Db::System.new(options)
        end
      end
    end
  end
end
