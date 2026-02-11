# frozen_string_literal: true

require "test_helper"

class Markdown::CopyMarkdownTest < ActiveSupport::TestCase
  SOURCE_DIR = File.expand_path("../../source", __dir__)

  MARKDOWN_WITH_NOTICE = <<~MARKDOWN
    **DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

    My Guide
    ========

    Short summary.

    --------------------------------------------------------------------------------

    ## Intro

    Hello.
  MARKDOWN

  test "HTML output includes copy markdown UI and template" do
    output = render_markdown(MARKDOWN_WITH_NOTICE, epub: false)

    assert_includes output, "id=\"copy-markdown-button\""
    assert_includes output, "images/icon_copy.svg"
    assert_includes output, "images/icon_check.svg"

    template = html_document(output).at_css("template#guide-markdown")
    assert template, "Expected guide markdown template to be present"

    assert_equal "My Guide", template.text.lines.first&.chomp
    assert_includes template.text, "## Intro"
    assert_not_includes template.text, "DO NOT READ THIS FILE ON GITHUB"
  end

  test "EPUB output omits copy markdown UI and template" do
    output = render_markdown(MARKDOWN_WITH_NOTICE, epub: true)

    assert_not_includes output, "copy-markdown-button"
    assert_nil html_document(output).at_css("template#guide-markdown")
  end

  private
    def render_markdown(markdown, epub:)
      view = ActionView::Base.with_empty_template_cache.with_view_paths(
        [SOURCE_DIR],
        edge:         nil,
        version:      nil,
        path:         "test.html",
        epub:         "epub/test.epub",
        language:     nil,
        direction:    "ltr",
        uuid:         "00000000-0000-0000-0000-000000000000",
        digest_paths: {}
      )
      view.extend RailsGuides::Helpers

      layout = epub ? "epub/layout" : "layout"
      RailsGuides::Markdown.new(view: view, layout: layout, edge: nil, version: nil, epub: epub).render(markdown)
    end

    def html_document(html)
      if defined?(Nokogiri::HTML5)
        Nokogiri::HTML5(html)
      else
        Nokogiri::HTML(html)
      end
    end
end
