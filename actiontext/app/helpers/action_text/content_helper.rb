# frozen_string_literal: true

require "rails-html-sanitizer"

module ActionText
  module ContentHelper
    mattr_accessor(:sanitizer) { Rails::Html::Sanitizer.safe_list_sanitizer.new }
    mattr_accessor(:allowed_tags) { sanitizer.class.allowed_tags + [ ActionText::Attachment::TAG_NAME, "figure", "figcaption" ] }
    mattr_accessor(:allowed_attributes) { sanitizer.class.allowed_attributes + ActionText::Attachment::ATTRIBUTES }
    mattr_accessor(:scrubber)

    def render_action_text_content(content)
      self.prefix_partial_path_with_controller_namespace = false
      sanitize_action_text_content(render_action_text_attachments(content))
    end

    def sanitize_action_text_content(content)
      sanitizer.sanitize(content.to_html, tags: allowed_tags, attributes: allowed_attributes, scrubber: scrubber).html_safe
    end

    def render_action_text_attachments(content)
      content.render_attachments do |attachment|
        unless attachment.in?(content.gallery_attachments)
          attachment.node.tap do |node|
            node.inner_html = render(attachment, in_gallery: false).chomp
          end
        end
      end.render_attachment_galleries do |attachment_gallery|
        render(layout: attachment_gallery, object: attachment_gallery) do
          attachment_gallery.attachments.map do |attachment|
            attachment.node.inner_html = render(attachment, in_gallery: true).chomp
            attachment.to_html
          end.join.html_safe
        end.chomp
      end
    end
  end
end
