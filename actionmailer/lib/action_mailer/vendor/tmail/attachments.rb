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
            attachment = Attachment.new(Base64.decode64(part.body))
            attachment.original_filename = part.header["content-type"].params["name"].strip.dup
            attachment
          end
        }.compact
      end      
    end
  end
end