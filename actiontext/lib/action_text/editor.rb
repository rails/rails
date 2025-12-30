# frozen_string_literal: true

module ActionText
  class Editor # :nodoc:
    extend ActiveSupport::Autoload

    autoload :Configurator
    autoload :Registry

    attr_reader :options

    def initialize(options = {})
      @options = options
    end

    # Convert fragments served by the editor into the canonical form that Action Text stores.
    #
    #   def as_canonical(editable_fragment)
    #     editable_fragment.replace "my-editor-attachment" do |editor_attachment|
    #       ActionText::Attachment.from_attributes(
    #         "sgid" => editor_attachment["sgid"],
    #         "content-type" => editor_attachment["content-type"]
    #       )
    #     end
    #   end
    def as_canonical(editable_fragment)
      editable_fragment
    end

    # Convert fragments from the canonical form that Action Text stores into a format that is supported by the editor.
    #
    #   def as_editable(canonical_fragment)
    #     canonical_fragment.replace ActionText::Attachment.tag_name do |action_text_attachment|
    #       attachment_attributes = {
    #         "sgid" => action_text_attachment["sgid"],
    #         "content-type" => action_text_attachment["content-type"]
    #       }
    #
    #       ActionText::HtmlConversion.create_element("my-editor-attachment", attachment_attributes)
    #     end
    #   end
    def as_editable(canonical_fragment)
      canonical_fragment
    end

    def editor_name
      self.class.name.demodulize.delete_suffix("Editor").underscore
    end

    def editor_tag(...)
      Tag.new(editor_name, ...)
    end
  end

  class Editor::Tag # :nodoc:
    cattr_accessor(:id, instance_accessor: false) { 0 }

    attr_reader :editor_name
    attr_reader :options

    def initialize(editor_name, options = {})
      @editor_name = editor_name
      @options = options
    end

    def element_name
      "#{editor_name}-editor"
    end

    def render_in(view_context)
      options[:class] ||= "#{editor_name}-content"

      view_context.content_tag(element_name, nil, options)
    end
  end
end
