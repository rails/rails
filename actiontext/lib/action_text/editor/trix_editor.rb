# frozen_string_literal: true

module ActionText
  class Editor::TrixEditor < Editor # :nodoc:
    def as_canonical(editable_fragment)
      editable_fragment.replace(TrixAttachment::SELECTOR, &method(:from_trix_attachment))
    end

    def as_editable(canonical_fragment)
      canonical_fragment.replace(Attachment.tag_name, &method(:to_trix_attachment))
    end

    def editor_tag(...)
      Tag.new(editor_name, ...)
    end

    private
      def to_trix_attachment(node)
        attachment_attributes = node.attributes
        TrixAttachment.from_attributes(attachment_attributes)
      end

      def from_trix_attachment(node)
        trix_attachment = TrixAttachment.new(node)
        Attachment.from_attributes(trix_attachment.attributes)
      end
  end

  class Editor::TrixEditor::Tag < Editor::Tag # :nodoc:
    def render_in(view_context, ...)
      name = options.delete(:name)
      form = options.delete(:form)
      value = options.delete(:value)

      options[:input] ||= options[:id] ?
        "#{options[:id]}_#{editor_name}_input_#{name.to_s.gsub(/\[.*\]/, "")}" :
        "#{editor_name}_input_#{self.class.id += 1}"
      input_tag = view_context.hidden_field_tag(name, value, id: options[:input], form: form)

      input_tag + super
    end
  end
end
