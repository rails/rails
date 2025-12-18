# frozen_string_literal: true

module Rails
  module Generators
    class SystemTestGenerator < NamedBase # :nodoc:
      def check_if_system_tests_enabled!
        unless defined?(Rails::TestUnitRailtie) && Rails.application.config.generators.system_tests
          raise <<~ERR
            Please ensure `require "rails/test_unit/railtie"` is added to `config/application.rb` and `Rails.application.config.generators.system_tests` is set to `:test_unit` (default).
          ERR
        end
      end

      hook_for :system_tests, as: :system
    end
  end
end
