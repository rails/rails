# frozen_string_literal: true

require "abstract_unit"

module ActionDispatch
  module Routing
    class ConsoleFormatterTest < ActiveSupport::TestCase
      class ::MockFormatter
        def draw
        end

        def no_routes
        end

        def result
        end
      end

      class ::BadFormatter
      end

      def setup
        ActionDispatch::Routing::ConsoleFormatter.registered_formatters = {}
      end

      def test_route_formatter_registration
        ActionDispatch::Routing::ConsoleFormatter.register_formatter(MockFormatter)

        assert_includes ActionDispatch::Routing::ConsoleFormatter.registered_formatters.values, MockFormatter
      end

      def test_route_formatter_registration_with_custom_name
        ActionDispatch::Routing::ConsoleFormatter.register_formatter(MockFormatter, "test-formatter")

        assert_includes ActionDispatch::Routing::ConsoleFormatter.registered_formatters.keys, "test-formatter"
      end

      def test_route_formatter_registration_raises_if_not_given_valid_formatter
        assert_raises(ArgumentError) {
          ActionDispatch::Routing::ConsoleFormatter.register_formatter(BadFormatter)
        }
      end

      def test_route_formatter_generates_formatter_name
        ActionDispatch::Routing::ConsoleFormatter.register_formatter(MockFormatter)

        assert_includes ActionDispatch::Routing::ConsoleFormatter.registered_formatters.keys, "MockFormatter"
      end

      def test_route_formatter_registration_doesnt_register_multiple_formatters
        ActionDispatch::Routing::ConsoleFormatter.register_formatter(MockFormatter)

        formatter_count = ActionDispatch::Routing::ConsoleFormatter.registered_formatters.keys.size

        ActionDispatch::Routing::ConsoleFormatter.register_formatter(MockFormatter)
        assert_equal formatter_count, ActionDispatch::Routing::ConsoleFormatter.registered_formatters.keys.size
      end
    end
  end
end
