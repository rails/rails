=begin rdoc

= Attachment handling file

=end

require 'kconv'
require 'stringio'

module TMail
  class Attachment < StringIO
    attr_accessor :original_filename, :content_type
    alias quoted_filename original_filename
  end

  class Mail
    def has_attachments?
      attachment?(self) || multipart? && parts.any? { |part| attachment?(part) }
    end

    # Returns true if this part's content main type is text, else returns false.
    # By main type is meant "text/plain" is text.  "text/html" is text
    def text_content_type?
      self.header['content-type'] && (self.header['content-type'].main_type == 'text')
    end
  
    def inline_attachment?(part)
      part['content-id'] || (part['content-disposition'] && part['content-disposition'].disposition == 'inline' && !part.text_content_type?)
    end
  
    def attachment?(part)
      part.disposition_is_attachment? || (!part.content_type.nil? && !part.text_content_type?) unless part.multipart?
    end
  
    def attachments
      if multipart?
        parts.collect { |part| attachment(part) }.flatten.compact
      elsif attachment?(self)
        [attachment(self)]
      end
    end
  
    private
  
    def attachment(part)
      if part.multipart?
        part.attachments
      elsif attachment?(part)
        content   = part.body # unquoted automatically by TMail#body
        file_name = (part['content-location'] && part['content-location'].body) ||
                    part.sub_header('content-type', 'name') ||
                    part.sub_header('content-disposition', 'filename') ||
                    'noname'

        return if content.blank?

        attachment = TMail::Attachment.new(content)
        attachment.original_filename = file_name.strip unless file_name.blank?
        attachment.content_type = part.content_type
        attachment
      end
    end

  end
end
