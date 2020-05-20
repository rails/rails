# frozen_string_literal: true

class FormLabelComponent < ActionView::Base
  def initialize(form:)
    @form = form
  end

  # Returns ActionView::OutputBuffer.
  def render_in(view_context, &block)
    @view_context = view_context
    @output_buffer = ActionView::OutputBuffer.new

    template = ActionView::Template::Handlers::ERB.erb_implementation.new(<<~'erb', trim: true).src
      <%= @form.label :title do %>
        Test
      <% end %>
    erb

    eval(template)
  end
end

class FieldsForComponent < ActionView::Base
  def initialize(form:, comment:)
    @form = form
    @comment = comment
  end

  # Returns ActionView::OutputBuffer.
  def render_in(view_context, &block)
    @view_context = view_context
    @output_buffer = ActionView::OutputBuffer.new

    template = ActionView::Template::Handlers::ERB.erb_implementation.new(<<~'erb', trim: true).src
      <%= @form.fields_for "comment[]", @comment do |c| %>
        <%= c.text_field(:name) %>
      <% end %>
    erb

    eval(template)
  end
end

class FieldsComponent < ActionView::Base
  def initialize(form:)
    @form = form
  end

  # Returns ActionView::OutputBuffer.
  def render_in(view_context, &block)
    @view_context = view_context
    @output_buffer = ActionView::OutputBuffer.new

    template = ActionView::Template::Handlers::ERB.erb_implementation.new(<<~'erb', trim: true).src
      <%= @form.fields :comment do |c| %>
        <%= c.text_field(:dont_exist_on_model ) %>
      <% end %>
    erb

    eval(template)
  end
end
