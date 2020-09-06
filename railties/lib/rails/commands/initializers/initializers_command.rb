# frozen_string_literal: true

require 'rails/command/environment_argument'

module Rails
  module Command
    class InitializersCommand < Base # :nodoc:
      include EnvironmentArgument

      desc 'initializers', 'Print out all defined initializers in the order they are invoked by Rails.'
      def perform
        extract_environment_option_from_argument
        ENV['RAILS_ENV'] = options[:environment]

        require_application_and_environment!

        Rails.application.initializers.tsort_each do |initializer|
          say "#{initializer.context_class}.#{initializer.name}"
        end
      end
    end
  end
end
