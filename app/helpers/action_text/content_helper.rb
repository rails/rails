module ActionText
  module ContentHelper
    SANITIZER          = Rails::Html::Sanitizer.white_list_sanitizer
    ALLOWED_TAGS       = SANITIZER.allowed_tags + [ ActionText::Attachment::TAG_NAME, "figure", "figcaption" ]
    ALLOWED_ATTRIBUTES = SANITIZER.allowed_attributes + ActionText::Attachment::ATTRIBUTES

    def render_action_text_content(content)
      content = content.render_attachments do |attachment|
        unless attachment.in?(content.gallery_attachments)
          attachment.node.tap do |node|
            node.inner_html = render(attachment, in_gallery: false).chomp
          end
        end
      end

      content = content.render_attachment_galleries do |attachment_gallery|
        render(layout: attachment_gallery, object: attachment_gallery) do
          attachment_gallery.attachments.map do |attachment|
            attachment.node.inner_html = render(attachment, in_gallery: true).chomp
            attachment.to_html
          end.join("").html_safe
        end.chomp
      end

      sanitize content.to_html, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRIBUTES
    end
  end
end
