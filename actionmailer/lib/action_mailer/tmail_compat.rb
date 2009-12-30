module Mail
  class Message
    
    def set_content_type(*args)
      STDERR.puts("Message#set_content_type is deprecated, please just call Message#content_type with the same arguments.\n#{caller}")
      content_type(*args)
    end
    
  end
end