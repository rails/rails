module Mail
  class Message
    
    def set_content_type(*args)
      STDERR.puts("Message#set_content_type is deprecated, please just call Message#content_type with the same arguments.\n#{caller}")
      content_type(*args)
    end
    
    alias :old_transfer_encoding :transfer_encoding
    def transfer_encoding(value = nil)
      if value
        STDERR.puts("Message#transfer_encoding is deprecated, please call Message#content_transfer_encoding with the same arguments.\n#{caller}")
        content_transfer_encoding(value)
      else
        old_transfer_encoding
      end
    end
    
  end
end