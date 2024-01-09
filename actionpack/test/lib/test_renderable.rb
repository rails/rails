# frozen_string_literal: true

class TestRenderable
  def render_in(_view_context, &block)
    if block_given?
      "<h1>#{block.call}</h1>"
    else
      "Hello, World!"
    end
  end

  def format
    :html
  end
end
