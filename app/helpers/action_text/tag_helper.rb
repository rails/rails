module ActionText
  module TagHelper
    cattr_accessor(:id, instance_accessor: false) { 0 }

    def rich_text_area_tag(name, value = nil, options = {})
      options = options.symbolize_keys

      options[:input] ||= "trix_input_#{ActionText::TagHelper.id += 1}"
      options[:data] ||= {}
      options[:data][:direct_upload_url] = rails_direct_uploads_url
      options[:data][:blob_url_template] = rails_service_blob_url(":signed_id", ":filename")

      editor_tag = content_tag("trix-editor", "", options)
      input_tag = hidden_field_tag(name, value, id: options[:input])

      editor_tag + input_tag
    end
  end
end

module ActionView::Helpers
  class Tags::ActionText < Tags::Base
    delegate :dom_id, to: ActionView::RecordIdentifier

    def render
      options = @options.stringify_keys
      add_default_name_and_id(options)
      options["input"] ||= dom_id(object, [options["id"], :trix_input].compact.join("_"))
      @template_object.rich_text_area_tag(options.delete("name"), editable_value, options)
    end

    def editable_value
      value.try(:to_trix_html)
    end
  end

  module FormHelper
    def rich_text_area(object_name, method, options = {})
      Tags::ActionText.new(object_name, method, self, options).render
    end
  end

  class FormBuilder
    def rich_text_area(method, options = {})
      @template.rich_text_area(@object_name, method, objectify_options(options))
    end
  end
end
