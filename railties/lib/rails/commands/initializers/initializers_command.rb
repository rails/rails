# frozen_string_literal: true

module Rails
  module Command
    class InitializersCommand < Base # :nodoc:
      desc "initializers", "Print out all defined initializers in the order they are invoked by Rails."
      def perform
        require_application_and_environment!

        Rails.application.initializers.tsort_each do |initializer|
          say "#{initializer.context_class}.#{initializer.name}"
        end
      end
    end
  end
end
