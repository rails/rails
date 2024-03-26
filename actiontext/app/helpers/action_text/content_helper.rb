# frozen_string_literal: true

require "rails-html-sanitizer"

module ActionText
  module ContentHelper
    mattr_accessor(:sanitizer, default: Rails::HTML4::Sanitizer.safe_list_sanitizer.new)
    mattr_accessor(:allowed_tags)
    mattr_accessor(:allowed_attributes)
    mattr_accessor(:scrubber)

    def render_action_text_content(content)
      self.prefix_partial_path_with_controller_namespace = false
      sanitize_action_text_content(render_action_text_attachments(content))
    end

    def sanitize_content_attachment(content_attachment)
      sanitizer.sanitize(
        content_attachment,
        tags: sanitizer_allowed_tags,
        attributes: sanitizer_allowed_attributes,
        scrubber: scrubber,
      )
    end

    def sanitize_action_text_content(content)
      sanitizer.sanitize(
        content.to_html,
        tags: sanitizer_allowed_tags,
        attributes: sanitizer_allowed_attributes,
        scrubber: scrubber,
      ).html_safe
    end

    def render_action_text_attachments(content)
      content.render_attachments do |attachment|
        unless attachment.in?(content.gallery_attachments)
          attachment.node.tap do |node|
            node.inner_html = render_action_text_attachment attachment, locals: { in_gallery: false }
          end
        end
      end.render_attachment_galleries do |attachment_gallery|
        render(layout: attachment_gallery, object: attachment_gallery) do
          attachment_gallery.attachments.map do |attachment|
            attachment.node.inner_html = render_action_text_attachment attachment, locals: { in_gallery: true }
            attachment.to_html
          end.join.html_safe
        end.chomp
      end
    end

    def render_action_text_attachment(attachment, locals: {}) # :nodoc:
      options = { locals: locals, object: attachment, partial: attachment }

      if attachment.respond_to?(:to_attachable_partial_path)
        options[:partial] = attachment.to_attachable_partial_path
      end

      if attachment.respond_to?(:model_name)
        options[:as] = attachment.model_name.element
      end

      render(**options).chomp
    end

    def sanitizer_allowed_tags
      allowed_tags || (sanitizer.class.allowed_tags + [ ActionText::Attachment.tag_name, "figure", "figcaption" ])
    end

    def sanitizer_allowed_attributes
      allowed_attributes || (sanitizer.class.allowed_attributes + ActionText::Attachment::ATTRIBUTES)
    end
  end
end
