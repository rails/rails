# frozen_string_literal: true

module ActionText
  class Editor::TrixEditor < Editor # :nodoc:
    attr_accessor :id

    def initialize(...)
      super
      @id = 0
    end

    def rich_text_area_tag(view_context, name, value = nil, options = {})
      form = options.delete(:form)

      options[:input] ||=
        if options[:id]
          "#{options[:id]}_trix_input_#{name.to_s.gsub(/\[.*\]/, "")}"
        else
          "trix_input_#{self.id += 1}"
        end
      options[:class] ||= "trix-content"

      editor_tag = view_context.content_tag("trix-editor", "", options)
      input_tag = view_context.hidden_field_tag(name, value.try(:to_editor_html) || value, id: options[:input], form: form)

      input_tag + editor_tag
    end

    def fill_in_rich_text_area(page, locator = nil, with:)
      page.find(:rich_text_area, locator).execute_script("this.editor.loadHTML(arguments[0])", with.to_s)
    end
  end
end
