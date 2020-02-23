# frozen_string_literal: true

class TestComponent < ActionView::Base
  delegate :render, to: :view_context

  def initialize(title:)
    @title = title
  end

  # Entrypoint for rendering. Called by ActionView::RenderingHelper#render.
  #
  # Returns ActionView::OutputBuffer.
  def render_in(view_context, &block)
    self.class.compile
    @view_context = view_context
    @content = view_context.capture(&block) if block_given?
    rendered_template
  end

  def self.template
    <<~'erb'
    <span title="<%= title %>"><%= content %> (<%= render(plain: "Inline render") %>)</span>
    erb
  end

  def self.compile
    @compiled ||= nil
    return if @compiled

    class_eval(
      "def rendered_template; @output_buffer = ActionView::OutputBuffer.new; " +
      ActionView::Template::Handlers::ERB.erb_implementation.new(template, trim: true).src +
      "; end"
    )

    @compiled = true
  end

private
  attr_reader :content, :title, :view_context
end
