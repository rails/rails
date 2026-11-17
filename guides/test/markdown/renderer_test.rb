# frozen_string_literal: true

require "test_helper"

class Markdown::RendererTest < ActiveSupport::TestCase
  def renderer
    RailsGuides::Markdown::Renderer.new
  end

  test "link returns an anchor tag" do
    assert_equal "<a href=\"http://example.com\">example</a>", renderer.link("http://example.com", nil, "example")
    assert_equal "<a href=\"http://example.com\" title=\"title\">example</a>", renderer.link("http://example.com", "title", "example")
  end

  test "link to the API" do
    assert_equal "<a href=\"https://api.rubyonrails.org/\">Rails</a>", renderer.link("https://api.rubyonrails.org", nil, "Rails")
  end

  test "link to a versioned API" do
    assert_equal "<a href=\"https://api.rubyonrails.org/v7.0\">Rails</a>", renderer.link("https://api.rubyonrails.org/v7.0", nil, "Rails")
  end

  test "link to the edge API" do
    renderer.edge = true
    assert_equal "<a href=\"https://edgeapi.rubyonrails.org\">Rails</a>", renderer.link("https://api.rubyonrails.org", nil, "Rails")
  ensure
    renderer.edge = false
  end
end
