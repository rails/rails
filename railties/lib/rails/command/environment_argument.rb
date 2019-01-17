# frozen_string_literal: true

require "active_support"

module Rails
  module Command
    module EnvironmentArgument #:nodoc:
      extend ActiveSupport::Concern

      included do
        class_option :environment, aliases: "-e", type: :string,
          desc: "Specifies the environment to run this console under (test/development/production)."
      end

      private
        def extract_environment_option_from_argument
          if options[:environment]
            self.options = options.merge(environment: acceptable_environment(options[:environment]))
          else
            self.options = options.merge(environment: Rails::Command.environment)
          end
        end

        def acceptable_environment(env = nil)
          if available_environments.include? env
            env
          else
            %w( production development test ).detect { |e| e =~ /^#{env}/ } || env
          end
        end

        def available_environments
          Dir["config/environments/*.rb"].map { |fname| File.basename(fname, ".*") }
        end
    end
  end
end
