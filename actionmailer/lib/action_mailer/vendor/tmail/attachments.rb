require 'stringio'

module TMail
  class Attachment < StringIO
    attr_accessor :original_filename, :content_type
  end

  class Mail
    def has_attachments?
      multipart? && parts.any? { |part| part.header["content-type"].main_type != "text" }
    end

    def attachments
      if multipart?
        parts.collect { |part| 
          if part.header["content-type"].main_type != "text"
            content   = part.body.unpack("m")[0]
            content   = part.body if content.blank?
            file_name = part.header["content-type"].params["name"]
            
            next if file_name.blank? || content.blank?
            
            attachment = Attachment.new(content)
            attachment.original_filename = file_name.strip.dup
            attachment
          end
        }.compact
      end      
    end
  end
end