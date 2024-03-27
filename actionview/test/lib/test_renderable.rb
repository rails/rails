# frozen_string_literal: true

class TestRenderable
  def render_in(view_context, **options, &block)
    if block
      view_context.render html: block.call
    else
      view_context.render inline: <<~ERB.strip, **options
        <h1>Hello, <%= local_assigns.fetch(:name, "World") %>!</h1>
      ERB
    end
  end

  def format
    :html
  end
end
