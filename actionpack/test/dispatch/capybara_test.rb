# frozen_string_literal: true

require "abstract_unit"
require "capybara/minitest"
require "rails/testing/capybara_extensions"

Rails::Testing::CapybaraExtensions.install :element

class CapybaraTest < ActionDispatch::IntegrationTest
  include Capybara::Minitest::Assertions

  def app
    self.class
  end

  def self.routes
    @routes ||= ActionDispatch::Routing::RouteSet.new
  end

  def self.call(env)
    routes.call(env)
  end

  class RendersController < ActionController::Base
    def create
      render params.permit(:inline, :locals)
    end
  end

  routes.draw do
    post "/render" => "capybara_test/renders#create"
  end

  def page
    Capybara.string(document_root_element)
  end

  test "can utilize Capybara assertions" do
    post "/render", params: { inline: <<~ERB }
      <div id="element">Content</div>
    ERB

    assert_selector :element, "div", id: "element", text: "Content"
  end

  test "can utilize Action View data: filter" do
    post "/render", params: { inline: <<~ERB }
      <%= tag.div data: { key: "value" } %>
    ERB

    assert_selector :element, data: { key: "value" }
  end

  test "can utilize Action View aria: filter" do
    post "/render", params: { inline: <<~ERB }
      <%= tag.div aria: { labelledby: "id" } %>
    ERB

    assert_selector :element, aria: { labelledby: "id" }
  end
end
