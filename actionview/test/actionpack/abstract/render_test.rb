require 'abstract_unit'

module AbstractController
  module Testing

    class ControllerRenderer < AbstractController::Base
      include AbstractController::Rendering
      include ActionView::Rendering

      def _prefixes
        %w[renderer]
      end

      self.view_paths = [ActionView::FixtureResolver.new(
        "template.erb" => "With Template",
        "renderer/default.erb" => "With Default",
        "renderer/string.erb" => "With String",
        "renderer/symbol.erb" => "With Symbol",
        "string/with_path.erb" => "With String With Path",
        "some/file.erb" => "With File"
      )]

      def template
        render :template => "template"
      end

      def file
        render :file => "some/file"
      end

      def inline
        render :inline => "With <%= :Inline %>"
      end

      def text
        render :text => "With Text"
      end

      def default
        render
      end

      def string
        render "string"
      end

      def string_with_path
        render "string/with_path"
      end

      def symbol
        render :symbol
      end
    end

    class TestRenderer < ActiveSupport::TestCase

      def setup
        @controller = ControllerRenderer.new
      end

      def test_render_template
        @controller.process(:template)
        assert_equal "With Template", @controller.response_body
      end

      def test_render_file
        @controller.process(:file)
        assert_equal "With File", @controller.response_body
      end

      def test_render_inline
        @controller.process(:inline)
        assert_equal "With Inline", @controller.response_body
      end

      def test_render_text
        @controller.process(:text)
        assert_equal "With Text", @controller.response_body
      end

      def test_render_default
        @controller.process(:default)
        assert_equal "With Default", @controller.response_body
      end

      def test_render_string
        @controller.process(:string)
        assert_equal "With String", @controller.response_body
      end

      def test_render_symbol
        @controller.process(:symbol)
        assert_equal "With Symbol", @controller.response_body
      end

      def test_render_string_with_path
        @controller.process(:string_with_path)
        assert_equal "With String With Path", @controller.response_body
      end
    end
  end
end
