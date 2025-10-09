# frozen_string_literal: true

module ActionText
  class Editor::TrixEditor < Editor # :nodoc:
    def to_action_text_html(editor_html)
      Fragment.wrap(super).replace(TrixAttachment::SELECTOR) do |node|
        trix_attachment = TrixAttachment.new(node)
        Attachment.from_attributes(trix_attachment.attributes)
      end
    end

    def to_editor_html(action_text_html)
      Fragment.wrap(super).replace(Attachment.tag_name) do |node|
        attachment_attributes = node.attributes
        TrixAttachment.from_attributes(attachment_attributes)
      end
    end

    def editor_tag(options = {})
      Tag.new(options)
    end

    class Tag
      cattr_accessor(:id, instance_accessor: false) { 0 }

      attr_reader :options
      attr_reader :name
      attr_reader :value

      def initialize(options = {})
        @options = options
        @name = options.delete(:name)
        @value = options.delete(:value)
      end

      def render_in(view_context)
        form = options.delete(:form)

        options[:input] ||= options[:id] ?
          "#{options[:id]}_trix_input_#{name.to_s.gsub(/\[.*\]/, "")}" :
          "trix_input_#{TrixEditor::Tag.id += 1}"
        options[:class] ||= "trix-content"

        editor_tag = view_context.content_tag("trix-editor", "", options)
        input_tag = view_context.hidden_field_tag(name, value.try(:to_editor_html) || value, id: options[:input], form: form)

        input_tag + editor_tag
      end
    end
  end
end
