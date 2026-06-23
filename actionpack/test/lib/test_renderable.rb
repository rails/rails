# frozen_string_literal: true

class TestRenderable
  def render_in(view_context, **)
    if block_given?
      view_context.render(html: yield)
    else
      view_context.render(inline: <<~ERB.strip, **)
        Hello, <%= local_assigns[:name] || "World" %>!
      ERB
    end
  end

  def format
    :html
  end
end
