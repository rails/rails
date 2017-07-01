require "active_support"

module Rails
  module Command
    module EnvironmentArgument #:nodoc:
      extend ActiveSupport::Concern

      included do
        argument :environment, optional: true, banner: "environment"
      end

      private
        def extract_environment_option_from_argument
          if environment
            self.options = options.merge(environment: acceptable_environment(environment))
          elsif !options[:environment]
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
