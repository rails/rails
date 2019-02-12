# frozen_string_literal: true

require "abstract_unit"

module RenderRelativePathPartial
  class BasicController < ActionController::Base
    self.view_paths = [ActionView::FixtureResolver.new(
      "render_relative_path_partial/basic/basic.html.erb" => "Hi! <%= render partial: './nested/nested' %>",
      "render_relative_path_partial/basic/nested/_nested.html.erb" => "<%= render partial: '../deeply/nested' %>",
      "render_relative_path_partial/basic/deeply/_nested.html.erb" => "Deeply Nested Partial"
    )]

    def basic
      render action: "basic"
    end
  end

  class TestPartial < Rack::TestCase
    testing BasicController

    test "correct resolution of partials specified by relative paths" do
      get :basic
      assert_response("Hi! Deeply Nested Partial")
    end
  end
end
