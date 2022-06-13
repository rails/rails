# frozen_string_literal: true

require "rails-html-sanitizer"

module ActionText
  module ContentHelper
    mattr_accessor(:sanitizer) { ActionText::Document.default_sanitizer }
    mattr_accessor(:allowed_tags) { sanitizer.class.allowed_tags + [ ActionText::Attachment.tag_name, "figure", "figcaption" ] }
    mattr_accessor(:allowed_attributes) { sanitizer.class.allowed_attributes + ActionText::Attachment::ATTRIBUTES }
    mattr_accessor(:scrubber)

    def render_action_text_content(content)
      self.prefix_partial_path_with_controller_namespace = false
      sanitize_action_text_content(render_action_text_attachments(content))
    end

    def sanitize_action_text_content(content)
      content = content.to_html unless sanitizer.try(:accepts_nodes?)
      sanitizer.sanitize(content, tags: allowed_tags, attributes: allowed_attributes, scrubber: scrubber).html_safe
    end

    def render_action_text_attachments(content)
      content.render_attachments do |attachment|
        unless attachment.in?(content.gallery_attachments)
          new_children = render_action_text_attachment attachment, locals: { in_gallery: false }
          ActionText::Document.replace_children(attachment.node, new_children)
        end
      end.render_attachment_galleries do |attachment_gallery|
        render(layout: attachment_gallery, object: attachment_gallery) do
          attachment_gallery.attachments.map do |attachment|
            new_children = render_action_text_attachment attachment, locals: { in_gallery: true }
            ActionText::Document.replace_children(attachment.node, new_children).to_html
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
  end
end
