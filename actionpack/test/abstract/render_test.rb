require 'abstract_unit'

module AbstractController
  module Testing

    class ControllerRenderer < AbstractController::Base
      include AbstractController::RenderingController

      self.view_paths = [ActionView::FixtureResolver.new(
        "default.erb" => "With Default",
        "template.erb" => "With Template",
        "some/file.erb" => "With File",
        "template_name.erb" => "With Template Name"
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

      def template_name
        render :_template_name => :template_name
      end

      def object
        render :_template => ActionView::TextTemplate.new("With Object")
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

      def test_render_template_name
        @controller.process(:template_name)
        assert_equal "With Template Name", @controller.response_body
      end

      def test_render_object
        @controller.process(:object)
        assert_equal "With Object", @controller.response_body
      end

    end
  end
end
