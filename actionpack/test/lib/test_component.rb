# frozen_string_literal: true

class TestComponent < ActionView::Base
  delegate :render, to: :view_context

  def initialize(title:)
    @title = title
  end

  def render_in(view_context)
    self.class.compile
    @view_context = view_context
    rendered_template
  end

  def format
    :html
  end

  def self.template
    <<~'erb'
    <span title="<%= title %>">(<%= render(plain: "Inline render") %>)</span>
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
  attr_reader :title, :view_context
end
