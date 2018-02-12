module ActiveText
  module TagHelper
    cattr_accessor(:id, instance_accessor: false) { 0 }

    def active_text_field_tag(name, value = nil, options = {})
      options = options.symbolize_keys
      options[:input] ||= "trix_input_#{ActiveText::TagHelper.id += 1}"

      editor_tag = content_tag("trix-editor", "", options)
      input_tag = hidden_field_tag(name, value, id: options[:input])

      editor_tag + input_tag
    end
  end
end

module ActionView::Helpers
  class Tags::ActiveText < Tags::Base
    include ActiveText::TagHelper

    delegate :dom_id, to: ActionView::RecordIdentifier

    def render
      options = @options.stringify_keys
      add_default_name_and_id(options)
      options["input"] ||= dom_id(object, [options["id"], :trix_input].compact.join("_"))
      active_text_field_tag(options.delete("name"), editable_value, options)
    end

    def editable_value
      value.try(:to_trix_html)
    end
  end

  module FormHelper
    def active_text_field(object_name, method, options = {})
      Tags::ActiveText.new(object_name, method, self, options).render
    end
  end

  class FormBuilder
    def active_text_field(method, options = {})
      @template.active_text_field(@object_name, method, objectify_options(options))
    end
  end
end
