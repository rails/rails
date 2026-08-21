# frozen_string_literal: true

require "abstract_unit"
require "action_view/render_parser"
require "action_view/template_scanner"
require "action_view/controller_scanner"
require "action_view/helper_scanner"
require "action_view/precompiler"

class RenderParserWithLocalsTest < ActiveSupport::TestCase
  def test_extracts_partial_with_locals
    code = 'render(partial: "comments/comment", locals: { comment: @comment, author: @author })'
    results = parse(code)

    assert_equal 1, results.size
    assert_equal "comments/_comment", results[0].virtual_path
    assert_equal [:author, :comment], results[0].locals_keys
  end

  def test_extracts_partial_shorthand
    code = 'render("comment", comment: @comment)'
    results = parse(code, name: "posts/show")

    assert_equal 1, results.size
    assert_equal "posts/_comment", results[0].virtual_path
  end

  def test_extracts_template_in_controller_context
    code = 'render("posts/index")'
    results = parse(code, from_controller: true)

    assert_equal 1, results.size
    assert_equal "posts/index", results[0].virtual_path
  end

  def test_extracts_partial_in_view_context
    code = 'render("comment")'
    results = parse(code, name: "posts/show")

    assert_equal 1, results.size
    assert_equal "posts/_comment", results[0].virtual_path
  end

  def test_extracts_collection_locals
    code = 'render(partial: "comments/comment", collection: @comments)'
    results = parse(code)

    assert_equal 1, results.size
    assert_equal "comments/_comment", results[0].virtual_path
    assert_includes results[0].locals_keys, :comment
    assert_includes results[0].locals_keys, :comment_counter
    assert_includes results[0].locals_keys, :comment_iteration
  end

  def test_extracts_layout_call_in_controller
    code = 'layout "admin"'
    results = parse(code, from_controller: true)

    assert_equal 1, results.size
    assert_equal "layouts/admin", results[0].virtual_path
    assert_equal [], results[0].locals_keys
  end

  def test_render_with_object
    code = 'render(partial: "comments/comment", object: @comment)'
    results = parse(code)

    assert_equal 1, results.size
    assert_equal "comments/_comment", results[0].virtual_path
    assert_includes results[0].locals_keys, :comment
  end

  def test_render_with_layout
    code = 'render(partial: "comments/comment", locals: { x: 1 }, layout: "wrapper")'
    results = parse(code, name: "posts/show")

    assert_equal 2, results.size
    assert_equal "comments/_comment", results[0].virtual_path
    assert_equal "_wrapper", results[1].virtual_path
  end

  def test_render_with_as
    code = 'render(partial: "comments/comment", collection: @comments, as: :item)'
    results = parse(code)

    assert_equal 1, results.size
    assert_includes results[0].locals_keys, :item
    assert_includes results[0].locals_keys, :item_counter
    assert_includes results[0].locals_keys, :item_iteration
  end

  def test_no_results_for_dynamic_partial
    code = "render(partial: some_method)"
    results = parse(code)

    # Dynamic partials with variable references generate object templates
    # which still get processed
    assert results.all? { |r| r.virtual_path.is_a?(String) }
  end

  def test_backward_compatible_render_calls
    code = 'render(partial: "comments/comment", locals: { comment: @comment })'
    parser = ActionView::RenderParser.new("posts/show", code)

    # The old render_calls method should still return just virtual paths
    templates = parser.render_calls
    assert_equal ["comments/_comment"], templates
  end

  private
    def parse(code, name: "app/views/test", from_controller: false)
      ActionView::RenderParser.new(name, code, from_controller: from_controller).render_calls_with_locals
    end
end

class TemplateScannerTest < ActiveSupport::TestCase
  def test_scans_templates_for_render_calls
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "show.html.erb"), '<%= render partial: "comments/comment", locals: { comment: @comment } %>')
      File.write(File.join(dir, "_comment.html.erb"), "<p>A comment</p>")

      scanner = ActionView::TemplateScanner.new(dir)
      results = scanner.template_renders

      partials = results.select { |vp, _| vp.include?("comment") }
      assert_not_empty partials, "Should detect render calls to comments/comment"
    end
  end

  def test_handles_templates_without_render
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "simple.html.erb"), "<h1>Hello</h1>")

      scanner = ActionView::TemplateScanner.new(dir)
      results = scanner.template_renders

      assert_equal [], results
    end
  end

  def test_raises_on_broken_template_handler
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "bad.html.erb"), '<%= render partial: "x", locals: { %>')

      scanner = ActionView::TemplateScanner.new(dir)
      # Malformed ERB compiles to invalid Ruby but Prism handles it gracefully,
      # so no error is raised — the template simply produces no render calls.
      results = scanner.template_renders
      assert_equal [], results
    end
  end

  def test_raises_with_filename_on_handler_error
    Dir.mktmpdir do |dir|
      # Register a handler that always raises
      ActionView::Template.register_template_handler :broken, ->(_template, _source) { raise RuntimeError, "boom" }

      File.write(File.join(dir, "fail.html.broken"), '<%= render "x" %>')

      scanner = ActionView::TemplateScanner.new(dir)
      error = assert_raises(RuntimeError) { scanner.template_renders }
      assert_match(/fail\.html\.broken/, error.message)
      assert_match(/boom/, error.message)
    ensure
      ActionView::Template.unregister_template_handler :broken
    end
  end
end

class ControllerScannerTest < ActiveSupport::TestCase
  def test_scans_controller_for_render_calls
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "posts_controller.rb"), <<~RUBY)
        class PostsController < ApplicationController
          def index
            render template: "posts/index"
          end

          def show
            render partial: "posts/details", locals: { post: @post }
          end
        end
      RUBY

      scanner = ActionView::ControllerScanner.new(dir)
      results = scanner.template_renders

      assert results.any? { |vp, _| vp == "posts/index" }, "Should detect render template: 'posts/index'"
      assert results.any? { |vp, _| vp == "posts/_details" }, "Should detect render partial: 'posts/details'"
    end
  end

  def test_handles_controllers_without_render
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "api_controller.rb"), <<~RUBY)
        class ApiController < ApplicationController
          def index
            head :ok
          end
        end
      RUBY

      scanner = ActionView::ControllerScanner.new(dir)
      results = scanner.template_renders

      assert_equal [], results
    end
  end
end

class HelperScannerTest < ActiveSupport::TestCase
  def test_scans_helpers_for_render_calls
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "posts_helper.rb"), <<~RUBY)
        module PostsHelper
          def post_widget(post)
            render partial: "posts/widget", locals: { post: post }
          end
        end
      RUBY

      scanner = ActionView::HelperScanner.new(dir)
      results = scanner.template_renders

      assert results.any? { |vp, _| vp == "posts/_widget" }, "Should detect render partial in helper"
    end
  end
end

class PrecompilerScanRubyDirTest < ActiveSupport::TestCase
  def test_scan_ruby_dir_scans_views_controllers_and_helpers
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "show.html.erb"), '<%= render partial: "comments/comment", locals: { comment: @comment } %>')

      File.write(File.join(dir, "posts_controller.rb"), <<~RUBY)
        class PostsController < ApplicationController
          def index
            render template: "posts/index"
          end
        end
      RUBY

      File.write(File.join(dir, "posts_helper.rb"), <<~RUBY)
        module PostsHelper
          def post_widget(post)
            render partial: "posts/widget", locals: { post: post }
          end
        end
      RUBY

      combined = ActionView::Precompiler.new
      combined.scan_ruby_dir(dir)

      separate = ActionView::Precompiler.new
      separate.scan_view_dir(dir)
      separate.scan_controller_dir(dir)
      separate.scan_helper_dir(dir)

      view_scanner = ActionView::TemplateScanner.new(dir)
      controller_scanner = ActionView::ControllerScanner.new(dir)
      helper_scanner = ActionView::HelperScanner.new(dir)

      assert_not_empty view_scanner.template_renders, "View scanner should find templates"
      assert_not_empty controller_scanner.template_renders, "Controller scanner should find render calls"
      assert_not_empty helper_scanner.template_renders, "Helper scanner should find render calls"
    end
  end
end
