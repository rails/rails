# frozen_string_literal: true

module ActionText
  class Editor::ProsemirrorEditor < Editor
    def rich_text_area_tag(view_context, name, value = nil, options = {})
      input_tag = view_context.hidden_field_tag(name, value.try(:to_editor_html) || value, form: options.delete(:form))
      editor_tag = view_context.content_tag(:div, nil, options.deep_merge!(data: { action_text_editor: self.name }))

      editor_tag + input_tag
    end
  end
end
