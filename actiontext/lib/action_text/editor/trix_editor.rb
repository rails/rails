# frozen_string_literal: true

module ActionText
  class Editor::TrixEditor < Editor # :nodoc:
    def to_action_text_html(editor_html)
      Fragment.wrap(super).replace(TrixAttachment::SELECTOR) do |node|
        trix_attachment = TrixAttachment.new(node)
        Attachment.from_attributes(trix_attachment.attributes)
      end
    end

    def to_editor_html(content)
      content
        .render_attachments(&:to_editor_attachment)
        .fragment.replace(Attachment.tag_name, &method(:to_trix_attachment))
        .to_html
    end

    def editor_tag(...)
      Tag.new(editor_name, ...)
    end

    private
      def to_trix_attachment(node)
        attachment_attributes = node.attributes
        TrixAttachment.from_attributes(attachment_attributes)
      end

    class Tag < Editor::Tag
      attr_reader :form
      attr_reader :value

      def render_in(view_context, ...)
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
end
