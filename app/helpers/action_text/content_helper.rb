module ActionText
  module ContentHelper
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

      content.to_html
    end
  end
end
