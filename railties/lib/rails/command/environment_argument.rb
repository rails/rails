# frozen_string_literal: true

require "active_support"
require "active_support/core_ext/class/attribute"

module Rails
  module Command
    module EnvironmentArgument # :nodoc:
      extend ActiveSupport::Concern

      included do
        class_option :environment, aliases: "-e", type: :string,
          desc: "The environment to run `#{self.command_name}` in (e.g. test / development / production)."
      end

      def initialize(...)
        super

        @environment_specified = options[:environment].present?

        if !@environment_specified
          self.options = options.merge(environment: Rails::Command.environment)
        elsif !available_environments.include?(options[:environment])
          self.options = options.merge(environment: expand_environment_name(options[:environment]))
        end
      end

      private
        def require_application!
          ENV["RAILS_ENV"] = environment
          super
        end

        def environment
          @environment ||= options[:environment]
        end

        def environment=(environment)
          @environment = environment
        end

        def environment_specified?
          @environment_specified
        end

        def available_environments
          @available_environments ||=
            Dir["config/environments/*.rb"].map { |filename| File.basename(filename, ".*") }
        end

        def expand_environment_name(name)
          %w[production development test].find { |full_name| full_name.start_with?(name) } || name
        end
    end
  end
end
