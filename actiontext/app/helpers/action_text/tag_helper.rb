# frozen_string_literal: true

# :markup: markdown

require "active_support/core_ext/object/try"
require "action_view/helpers/tags/placeholderable"

module ActionText
  module TagHelper
    cattr_accessor(:id, instance_accessor: false) { 0 }

    # Returns a `trix-editor` tag that instantiates the Trix JavaScript editor as
    # well as a hidden field that Trix will write to on changes, so the content will
    # be sent on form submissions.
    #
    # #### Options
    # *   `:class` - Defaults to "trix-content" so that default styles will be
    #     applied. Setting this to a different value will prevent default styles
    #     from being applied.
    # *   `[:data][:direct_upload_url]` - Defaults to `rails_direct_uploads_url`.
    # *   `[:data][:blob_url_template]` - Defaults to
    #     `rails_service_blob_url(":signed_id", ":filename")`.
    #
    #
    # #### Example
    #
    #     rich_textarea_tag "content", message.content
    #     # <input type="hidden" name="content" id="trix_input_post_1">
    #     # <trix-editor id="content" input="trix_input_post_1" class="trix-content" ...></trix-editor>
    def rich_textarea_tag(name, value = nil, options = {})
      options = options.symbolize_keys
      form = options.delete(:form)

      options[:input] ||= "trix_input_#{ActionText::TagHelper.id += 1}"
      options[:class] ||= "trix-content"

      options[:data] ||= {}
      options[:data][:direct_upload_url] ||= main_app.rails_direct_uploads_url
      options[:data][:blob_url_template] ||= main_app.rails_service_blob_url(":signed_id", ":filename")

      editor_tag = content_tag("trix-editor", "", options)
      input_tag = hidden_field_tag(name, value.try(:to_trix_html) || value, id: options[:input], form: form)

      input_tag + editor_tag
    end
    alias_method :rich_text_area_tag, :rich_textarea_tag
  end
end

module ActionView::Helpers
  class Tags::ActionText < Tags::Base
    include Tags::Placeholderable

    delegate :dom_id, to: ActionView::RecordIdentifier

    def render
      options = @options.stringify_keys
      add_default_name_and_id(options)
      options["input"] ||= dom_id(object, [options["id"], :trix_input].compact.join("_")) if object
      html_tag = @template_object.rich_textarea_tag(options.delete("name"), options.fetch("value") { value }, options.except("value"))
      error_wrapping(html_tag)
    end
  end

  module FormHelper
    # Returns a `trix-editor` tag that instantiates the Trix JavaScript editor as
    # well as a hidden field that Trix will write to on changes, so the content will
    # be sent on form submissions.
    #
    # #### Options
    # *   `:class` - Defaults to "trix-content" which ensures default styling is
    #     applied.
    # *   `:value` - Adds a default value to the HTML input tag.
    # *   `[:data][:direct_upload_url]` - Defaults to `rails_direct_uploads_url`.
    # *   `[:data][:blob_url_template]` - Defaults to
    #     `rails_service_blob_url(":signed_id", ":filename")`.
    #
    #
    # #### Example
    #     rich_textarea :message, :content
    #     # <input type="hidden" name="message[content]" id="message_content_trix_input_message_1">
    #     # <trix-editor id="content" input="message_content_trix_input_message_1" class="trix-content" ...></trix-editor>
    #
    #     rich_textarea :message, :content, value: "<h1>Default message</h1>"
    #     # <input type="hidden" name="message[content]" id="message_content_trix_input_message_1" value="<h1>Default message</h1>">
    #     # <trix-editor id="content" input="message_content_trix_input_message_1" class="trix-content" ...></trix-editor>
    def rich_textarea(object_name, method, options = {})
      Tags::ActionText.new(object_name, method, self, options).render
    end
    alias_method :rich_text_area, :rich_textarea
  end

  class FormBuilder
    # Wraps ActionView::Helpers::FormHelper#rich_textarea for form builders:
    #
    #     <%= form_with model: @message do |f| %>
    #       <%= f.rich_textarea :content %>
    #     <% end %>
    #
    # Please refer to the documentation of the base helper for details.
    def rich_textarea(method, options = {})
      @template.rich_textarea(@object_name, method, objectify_options(options))
    end
    alias_method :rich_text_area, :rich_textarea
  end
end
