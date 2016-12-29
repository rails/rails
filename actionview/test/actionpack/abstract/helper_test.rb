require "abstract_unit"

ActionController::Base.helpers_path = File.expand_path("../../../fixtures/helpers", __FILE__)

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

    class AbstractInvalidHelpers < AbstractHelpers
      include ActionController::Helpers

      path = File.expand_path("../../../fixtures/helpers_missing", __FILE__)
      $:.unshift(path)
      self.helpers_path = path
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
        e = assert_raise AbstractController::Helpers::MissingHelperError do
          AbstractHelpers.helper :missing
        end
        assert_equal "helpers/missing_helper.rb", e.path
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
      def test_controller_raise_error_about_real_require_problem
        e = assert_raise(LoadError) { AbstractInvalidHelpers.helper(:invalid_require) }
        assert_equal "No such file to load -- very_invalid_file_name.rb", e.message
      end

      def test_controller_raise_error_about_missing_helper
        e = assert_raise(AbstractController::Helpers::MissingHelperError) { AbstractInvalidHelpers.helper(:missing) }
        assert_equal "Missing helper file helpers/missing_helper.rb", e.message
      end

      def test_missing_helper_error_has_the_right_path
        e = assert_raise(AbstractController::Helpers::MissingHelperError) { AbstractInvalidHelpers.helper(:missing) }
        assert_equal "helpers/missing_helper.rb", e.path
      end
    end
  end
end
