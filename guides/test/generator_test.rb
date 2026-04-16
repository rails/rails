# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "rails_guides/generator"
require "tmpdir"

class GeneratorTest < ActiveSupport::TestCase
  def teardown
    # Reset class-level attributes that Generator sets globally
    RailsGuides::Markdown::Renderer.edge = nil
    RailsGuides::Markdown::Renderer.version = nil
  end

  test "generate creates new files and removes stale html/css/js files" do
    Dir.mktmpdir do |guides_dir|
      output_dir = File.join(guides_dir, "output")

      real_guides_dir = File.expand_path("..", __dir__)
      FileUtils.mkdir_p(File.join(guides_dir, "source"))
      %w[getting_started.md layout.html.erb _license.html.erb].each do |file|
        FileUtils.cp(
          File.join(real_guides_dir, "source", file),
          File.join(guides_dir, "source", file)
        )
      end

      assets_dir = File.join(guides_dir, "assets")
      FileUtils.mkdir_p(File.join(assets_dir, "javascripts"))

      style_dir = FileUtils.mkdir_p(File.join(assets_dir, "stylesrc"))
      style_files = %w[style.scss highlight.scss print.scss]
      style_files.each do |file|
        File.write(File.join(style_dir, file), "")
      end

      FileUtils.mkdir_p(output_dir)
      stale_html = File.join(output_dir, "stale_test_guide.html")
      FileUtils.touch(stale_html)

      css_dir = File.join(output_dir, "stylesheets")
      FileUtils.mkdir_p(css_dir)
      stale_css = File.join(css_dir, "old_stale_test.css")
      FileUtils.touch(stale_css)

      js_dir = File.join(output_dir, "javascripts")
      FileUtils.mkdir_p(js_dir)
      stale_js = File.join(js_dir, "old_stale_test.js")
      FileUtils.touch(stale_js)

      keep_file = File.join(output_dir, "keep_me_test_file.txt")
      FileUtils.touch(keep_file)

      generator = RailsGuides::Generator.new(
        edge: nil,
        version: "8.2",
        all: false,
        only: "getting_started",
        epub: false,
        language: nil,
        lint: false,
        guides_dir:
      )
      generator.generate

      assert_not File.exist?(stale_html), "Stale HTML should be removed"

      assert Dir.exist?(css_dir), "Stylesheets directory should be recreated"
      assert_not File.exist?(stale_css), "Stale CSS should be removed"

      assert Dir.exist?(js_dir), "Javascripts directory should be recreated"
      assert_not File.exist?(stale_js), "Stale JS should be removed"

      assert File.exist?(keep_file), "Non-HTML files should be preserved"

      getting_started_html = File.join(output_dir, "getting_started.html")
      assert File.size(getting_started_html) > 0, "Generated HTML should not be empty"

      css_files = Dir.glob(File.join(css_dir, "*.css"))
      style_files.each do |file|
        assert css_files.any? { |f| File.basename(f).start_with?("#{file.sub(".scss", "-")}") }, "#{file} should be compiled"
      end
    end
  end
end
