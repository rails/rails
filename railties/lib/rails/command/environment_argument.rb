# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext/class/attribute'

module Rails
  module Command
    module EnvironmentArgument #:nodoc:
      extend ActiveSupport::Concern

      included do
        no_commands do
          class_attribute :environment_desc, default: "Specifies the environment to run this #{self.command_name} under (test/development/production)."
        end
        class_option :environment, aliases: '-e', type: :string, desc: environment_desc
      end

      private
        def extract_environment_option_from_argument(default_environment: Rails::Command.environment)
          if options[:environment]
            self.options = options.merge(environment: acceptable_environment(options[:environment]))
          else
            self.options = options.merge(environment: default_environment)
          end
        end

        def acceptable_environment(env = nil)
          if available_environments.include? env
            env
          else
            %w( production development test ).detect { |e| /^#{env}/.match?(e) } || env
          end
        end

        def available_environments
          Dir['config/environments/*.rb'].map { |fname| File.basename(fname, '.*') }
        end
    end
  end
end
