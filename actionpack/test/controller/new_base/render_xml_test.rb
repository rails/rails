require "abstract_unit"

module RenderXml
  # This has no layout and it works
  class BasicController < ActionController::Base
    self.view_paths = [ActionView::FixtureResolver.new(
      "render_xml/basic/with_render_erb" => "Hello world!"
    )]
  end
end
