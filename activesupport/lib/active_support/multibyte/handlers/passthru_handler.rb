# Chars uses this handler when $KCODE is not set to 'UTF8'. Because this handler doesn't define any methods all call
# will be forwarded to String.
class ActiveSupport::Multibyte::Handlers::PassthruHandler #:nodoc:
  
  # Return the original byteoffset
  def self.translate_offset(string, byte_offset) #:nodoc:
    byte_offset
  end
end