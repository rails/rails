# frozen_string_literal: true

# :markup: markdown

require "active_support/core_ext/object/try"
require "action_view/helpers/tags/placeholderable"

module ActionText
  module TagHelper
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
    #     rich_text_area_tag "content", message.content
    #     # <input type="hidden" name="content" id="trix_input_post_1">
    #     # <trix-editor id="content" input="trix_input_post_1" class="trix-content" ...></trix-editor>
    def rich_text_area_tag(name, value = nil, options = {})
      editor = options.delete(:editor) { RichText.editor }
      options = options.symbolize_keys

      options[:data] ||= {}
      options[:data][:direct_upload_url] ||= main_app.rails_direct_uploads_url
      options[:data][:blob_url_template] ||= main_app.rails_service_blob_url(":signed_id", ":filename")

      editor.rich_text_area_tag(self, name, value, options)
    end
  end
end

module ActionView::Helpers
  class Tags::ActionText < Tags::Base
    include Tags::Placeholderable

    def render
      options = @options.stringify_keys
      add_default_name_and_id(options)
      html_tag = @template_object.rich_text_area_tag(options.delete("name"), options.fetch("value") { value }, options.except("value"))
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
    #     rich_text_area :message, :content
    #     # <input type="hidden" name="message[content]" id="message_content_trix_input_message_1">
    #     # <trix-editor id="content" input="message_content_trix_input_message_1" class="trix-content" ...></trix-editor>
    #
    #     rich_text_area :message, :content, value: "<h1>Default message</h1>"
    #     # <input type="hidden" name="message[content]" id="message_content_trix_input_message_1" value="<h1>Default message</h1>">
    #     # <trix-editor id="content" input="message_content_trix_input_message_1" class="trix-content" ...></trix-editor>
    def rich_text_area(object_name, method, options = {})
      Tags::ActionText.new(object_name, method, self, options).render
    end
  end

  class FormBuilder
    # Wraps ActionView::Helpers::FormHelper#rich_text_area for form builders:
    #
    #     <%= form_with model: @message do |f| %>
    #       <%= f.rich_text_area :content %>
    #     <% end %>
    #
    # Please refer to the documentation of the base helper for details.
    def rich_text_area(method, options = {})
      @template.rich_text_area(@object_name, method, objectify_options(options))
    end
  end
end
