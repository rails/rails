# frozen_string_literal: true

require "abstract_unit"

ActionController::Base.helpers_path = File.expand_path("../../fixtures/helpers", __dir__)

module AbstractController
  module Testing
    class ControllerWithHelpers < AbstractController::Base
      include AbstractController::Helpers
      include AbstractController::Rendering
      include ActionView::Rendering

      def with_module
        render inline: "Module <%= included_method %>"
      end
    end

    module HelperyTest
      def included_method
        "Included"
      end
    end

    class AbstractHelpers < ControllerWithHelpers
      helper(HelperyTest) do
        def helpery_test
          "World"
        end
      end

      helper :abc

      def with_block
        render inline: "Hello <%= helpery_test %>"
      end

      def with_symbol
        render inline: "I respond to bare_a: <%= respond_to?(:bare_a) %>"
      end
    end

    class ::HelperyTestController < AbstractHelpers
      clear_helpers
    end

    class AbstractHelpersBlock < ControllerWithHelpers
      helper do
        include AbstractController::Testing::HelperyTest
      end
    end

    class TestHelpers < ActiveSupport::TestCase
      def setup
        @controller = AbstractHelpers.new
      end

      def test_helpers_with_block
        @controller.process(:with_block)
        assert_equal "Hello World", @controller.response_body
      end

      def test_helpers_with_module
        @controller.process(:with_module)
        assert_equal "Module Included", @controller.response_body
      end

      def test_helpers_with_symbol
        @controller.process(:with_symbol)
        assert_equal "I respond to bare_a: true", @controller.response_body
      end

      def test_declare_missing_helper
        e = assert_raise NameError do
          AbstractHelpers.helper :missing
        end
        assert_equal "uninitialized constant MissingHelper", e.message
      end

      def test_helpers_with_module_through_block
        @controller = AbstractHelpersBlock.new
        @controller.process(:with_module)
        assert_equal "Module Included", @controller.response_body
      end
    end

    class ClearHelpersTest < ActiveSupport::TestCase
      def setup
        @controller = HelperyTestController.new
      end

      def test_clears_up_previous_helpers
        @controller.process(:with_symbol)
        assert_equal "I respond to bare_a: false", @controller.response_body
      end

      def test_includes_controller_default_helper
        @controller.process(:with_block)
        assert_equal "Hello Default", @controller.response_body
      end
    end

    class InvalidHelpersTest < ActiveSupport::TestCase
      def test_controller_raise_error_about_missing_helper
        e = assert_raise(NameError) { AbstractHelpers.helper(:missing) }
        assert_equal "uninitialized constant MissingHelper", e.message
      end
    end
  end
end
