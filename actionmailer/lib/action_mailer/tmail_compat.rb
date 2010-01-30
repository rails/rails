module Mail
  class Message
    
    def set_content_type(*args)
      ActiveSupport::Deprecation.warn('Message#set_content_type is deprecated, please just call ' <<
                                      'Message#content_type with the same arguments', caller[0,2])
      content_type(*args)
    end
    
    alias :old_transfer_encoding :transfer_encoding
    def transfer_encoding(value = nil)
      if value
        ActiveSupport::Deprecation.warn('Message#transfer_encoding is deprecated, please call ' <<
                                        'Message#content_transfer_encoding with the same arguments', caller[0,2])
        content_transfer_encoding(value)
      else
        old_transfer_encoding
      end
    end

    def transfer_encoding=(value)
      ActiveSupport::Deprecation.warn('Message#transfer_encoding= is deprecated, please call ' <<
                                      'Message#content_transfer_encoding= with the same arguments', caller[0,2])
      self.content_transfer_encoding = value
    end

    def original_filename
      ActiveSupport::Deprecation.warn('Message#original_filename is deprecated, ' <<
                                      'please call Message#filename', caller[0,2])
      filename
    end
    
  end
end