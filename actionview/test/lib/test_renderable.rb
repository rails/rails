# frozen_string_literal: true

class TestRenderable
  def render_in(view_context, locals: {}, **)
    if block_given?
      yield.to_s
    else
      "Hello, #{locals[:name] || "World"}!"
    end
  end
end
