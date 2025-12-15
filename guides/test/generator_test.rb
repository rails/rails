# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "rails_guides/generator"

class GeneratorTest < ActiveSupport::TestCase
  GUIDES_DIR = File.expand_path("..", __dir__)
  OUTPUT_DIR = File.join(GUIDES_DIR, "output")

  test "generate creates new files and removes stale html/css/js files" do
    FileUtils.mkdir_p(OUTPUT_DIR)

    stale_html = File.join(OUTPUT_DIR, "stale_test_guide.html")
    FileUtils.touch(stale_html)

    css_dir = File.join(OUTPUT_DIR, "stylesheets")
    FileUtils.mkdir_p(css_dir)
    stale_css = File.join(css_dir, "old_stale_test.css")
    FileUtils.touch(stale_css)

    js_dir = File.join(OUTPUT_DIR, "javascripts")
    FileUtils.mkdir_p(js_dir)
    stale_js = File.join(js_dir, "old_stale_test.js")
    FileUtils.touch(stale_js)

    keep_file = File.join(OUTPUT_DIR, "keep_me_test_file.txt")
    FileUtils.touch(keep_file)

    generator = RailsGuides::Generator.new(
      edge: nil,
      version: "8.2",
      all: false,
      only: "getting_started",
      epub: false,
      language: nil,
      lint: false
    )
    generator.generate

    assert_not File.exist?(stale_html), "Stale HTML should be removed"

    assert Dir.exist?(css_dir), "Stylesheets directory should be recreated"
    assert_not File.exist?(stale_css), "Stale CSS should be removed"

    assert Dir.exist?(js_dir), "Javascripts directory should be recreated"
    assert_not File.exist?(stale_js), "Stale JS should be removed"

    assert File.exist?(keep_file), "Non-HTML files should be preserved"

    assert File.exist?(File.join(OUTPUT_DIR, "getting_started.html")), "Guide should be generated"

    FileUtils.rm_rf(OUTPUT_DIR) # Clean up
  end
end
