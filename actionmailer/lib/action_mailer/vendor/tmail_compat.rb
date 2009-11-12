# TMail Compatibility File
# Created in 1.2 of Mail.  Will be deprecated
STDERR.puts("DEPRECATION WARNING, Mail running in TMail compatibility mode.  This will be deprecated soon.")

module Mail
  
  def Mail.parse(string)
    STDERR.puts("DEPRECATION WARNING, Mail.parse(string) is deprecated, please use Mail.new")
    ::Mail.new(string)
  end
  
end

class Mail::Message
  
  def set_content_type(*args)
    STDERR.puts("DEPRECATION WARNING, Message#set_content_type is deprecated, please use Message#content_type")
    content_type(args)
  end
  
  def set_content_disposition(*args)
    STDERR.puts("DEPRECATION WARNING, Message#set_content_disposition is deprecated, please use Message#content_disposition")
    content_disposition(args)
  end

  def encoding=(val)
    STDERR.puts("DEPRECATION WARNING, Message#encoding= is deprecated, please use Message#content_transfer_encoding")
    content_transfer_encoding(val)
  end
  
  def quoted_body
    STDERR.puts("DEPRECATION WARNING, Body#quoted_body is deprecated, please use Message => Body#encoded")
    body.decoded
  end
  
end
