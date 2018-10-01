# frozen_string_literal: true

module AbstractController
  module Railties
    module RoutesHelpers
      def self.with(routes, include_path_helpers = true)
        Module.new do
          define_method(:inherited) do |klass|
            super(klass)

            routes.include_helpers klass, include_path_helpers
          end
        end
      end
    end
  end
end
