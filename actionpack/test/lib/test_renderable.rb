# frozen_string_literal: true

class TestRenderable
  def render_in(view_context, locals: {}, **options, &block)
    if block
      view_context.render html: block.call
    else
      view_context.render inline: <<~ERB.strip, locals: locals
        Hello, <%= local_assigns.fetch(:name, "World") %>!
      ERB
    end
  end

  def format
    :html
  end
end
