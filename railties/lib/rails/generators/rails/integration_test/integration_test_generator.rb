# frozen_string_literal: true

module Rails
  module Generators
    class IntegrationTestGenerator < NamedBase # :nodoc:
      def check_if_test_unit_loaded!
        unless defined?(Rails::TestUnitRailtie)
          raise <<~ERR
            Please ensure `require "rails/test_unit/railtie"` is added to `config/application.rb`.
          ERR
        end
      end

      hook_for :integration_tool, as: :integration
    end
  end
end
