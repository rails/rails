# frozen_string_literal: true

require "active_support"

module Rails
  module Command
    module EnvironmentArgument #:nodoc:
      extend ActiveSupport::Concern

      included do
        argument :environment, optional: true, banner: "environment"

        class_option :environment, aliases: "-e", type: :string,
          desc: "Specifies the environment to run this console under (test/development/production)."
      end

      private
        def extract_environment_option_from_argument
          if environment
            self.options = options.merge(environment: acceptable_environment(environment))

            ActiveSupport::Deprecation.warn "Passing the environment's name as a " \
                                            "regular argument is deprecated and "  \
                                            "will be removed in the next Rails "   \
                                            "version. Please, use the -e option "  \
                                            "instead."
          elsif options[:environment]
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
