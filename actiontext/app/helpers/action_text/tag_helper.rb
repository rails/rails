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
    #     rich_textarea_tag "content", message.content
    #     # <input type="hidden" name="content" id="trix_input_post_1">
    #     # <trix-editor id="content" input="trix_input_post_1" class="trix-content" ...></trix-editor>
    #
    #     rich_textarea_tag "content", nil do
    #       "<h1>Default content</h1>"
    #     end
    #     # <input type="hidden" name="content" id="trix_input_post_1" value="&lt;h1&gt;Default content&lt;/h1&gt;">
    #     # <trix-editor id="content" input="trix_input_post_1" class="trix-content" ...></trix-editor>
    def rich_textarea_tag(name, value = nil, options = {}, &block)
      value = capture(&block) if value.nil? && block_given?
      options = options.symbolize_keys

      options[:value] ||= value.try(:to_editor_html) || value
      options[:name]  ||= name

      options[:data] ||= {}
      options[:data][:direct_upload_url] ||= main_app.rails_direct_uploads_url
      options[:data][:blob_url_template] ||= main_app.rails_service_blob_url(":signed_id", ":filename")

      render RichText.editor.editor_tag(options)
    end
    alias_method :rich_text_area_tag, :rich_textarea_tag
  end
end

module ActionView::Helpers
  class Tags::ActionText < Tags::Base
    include Tags::Placeholderable

    def render(&block)
      options = @options.stringify_keys
      add_default_name_and_field(options)
      html_tag = @template_object.rich_textarea_tag(options.delete("name"), options.fetch("value") { value }, options.except("value"), &block)
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
    #     # <input type="hidden" name="message[content]" id="message_content_trix_input_message_1" value="&lt;h1&gt;Default message&lt;/h1&gt;">
    #     # <trix-editor id="content" input="message_content_trix_input_message_1" class="trix-content" ...></trix-editor>
    #
    #     rich_textarea :message, :content do
    #       "<h1>Default message</h1>"
    #     end
    #     # <input type="hidden" name="message[content]" id="message_content_trix_input_message_1" value="&lt;h1&gt;Default message&lt;/h1&gt;">
    #     # <trix-editor id="content" input="message_content_trix_input_message_1" class="trix-content" ...></trix-editor>
    def rich_textarea(object_name, method, options = {}, &block)
      Tags::ActionText.new(object_name, method, self, options).render(&block)
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
    def rich_textarea(method, options = {}, &block)
      @template.rich_textarea(@object_name, method, objectify_options(options), &block)
    end
    alias_method :rich_text_area, :rich_textarea
  end
end
