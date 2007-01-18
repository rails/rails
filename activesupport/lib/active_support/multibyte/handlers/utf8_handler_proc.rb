# Methods in this handler call functions in the utf8proc ruby extension. These are significantly faster than the
# pure ruby versions. Chars automatically uses this handler when it can load the utf8proc extension. For
# documentation on handler methods see UTF8Handler.
class ActiveSupport::Multibyte::Handlers::UTF8HandlerProc < ActiveSupport::Multibyte::Handlers::UTF8Handler #:nodoc:
  class << self
    def normalize(str, form=ActiveSupport::Multibyte::DEFAULT_NORMALIZATION_FORM) #:nodoc:
      codepoints = str.unpack('U*')
      case form
        when :d
          utf8map(str, :stable)
        when :c
          utf8map(str, :stable, :compose)
        when :kd
          utf8map(str, :stable, :compat)
        when :kc
          utf8map(str, :stable, :compose, :compat)
        else
          raise ArgumentError, "#{form} is not a valid normalization variant", caller
      end
    end
    
    def decompose(str) #:nodoc:
      utf8map(str, :stable)
    end
    
    def downcase(str) #:nodoc:c
      utf8map(str, :casefold)
    end
    
    protected
    
    def utf8map(str, *option_array) #:nodoc:
      options = 0
      option_array.each do |option|
        flag = Utf8Proc::Options[option]
        raise ArgumentError, "Unknown argument given to utf8map." unless
          flag
        options |= flag
      end
      return Utf8Proc::utf8map(str, options)
    end
  end
end
