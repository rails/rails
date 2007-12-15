require 'active_support/multibyte/handlers/utf8_handler'
require 'active_support/multibyte/handlers/passthru_handler'

# Encapsulates all the functionality related to the Chars proxy.
module ActiveSupport::Multibyte #:nodoc:
  # Chars enables you to work transparently with multibyte encodings in the Ruby String class without having extensive
  # knowledge about the encoding. A Chars object accepts a string upon initialization and proxies String methods in an
  # encoding safe manner. All the normal String methods are also implemented on the proxy.
  #
  # String methods are proxied through the Chars object, and can be accessed through the +chars+ method. Methods
  # which would normally return a String object now return a Chars object so methods can be chained.
  #
  #   "The Perfect String  ".chars.downcase.strip.normalize #=> "the perfect string"
  #
  # Chars objects are perfectly interchangeable with String objects as long as no explicit class checks are made.
  # If certain methods do explicitly check the class, call +to_s+ before you pass chars objects to them.
  #
  #   bad.explicit_checking_method "T".chars.downcase.to_s
  #
  # The actual operations on the string are delegated to handlers. Theoretically handlers can be implemented for
  # any encoding, but the default handler handles UTF-8. This handler is set during initialization, if you want to
  # use you own handler, you can set it on the Chars class. Look at the UTF8Handler source for an example how to
  # implement your own handler. If you your own handler to work on anything but UTF-8 you probably also
  # want to override Chars#handler.
  #
  #   ActiveSupport::Multibyte::Chars.handler = MyHandler
  #
  # Note that a few methods are defined on Chars instead of the handler because they are defined on Object or Kernel
  # and method_missing can't catch them.
  class Chars
    
    attr_reader :string # The contained string
    alias_method :to_s, :string
    
    include Comparable
    
    # The magic method to make String and Chars comparable
    def to_str
      # Using any other ways of overriding the String itself will lead you all the way from infinite loops to
      # core dumps. Don't go there.
      @string
    end
    
    # Make duck-typing with String possible
    def respond_to?(method)
      super || @string.respond_to?(method) || handler.respond_to?(method) ||
        (method.to_s =~ /(.*)!/ && handler.respond_to?($1)) || false
    end
    
    # Create a new Chars instance.
    def initialize(str)
      @string = str.respond_to?(:string) ? str.string : str
    end
    
    # Returns -1, 0 or +1 depending on whether the Chars object is to be sorted before, equal or after the
    # object on the right side of the operation. It accepts any object that implements +to_s+. See String.<=>
    # for more details.
    def <=>(other); @string <=> other.to_s; end
    
    # Works just like String#split, with the exception that the items in the resulting list are Chars
    # instances instead of String. This makes chaining methods easier.
    def split(*args)
      @string.split(*args).map { |i| i.chars }
    end
    
    # Gsub works exactly the same as gsub on a normal string.
    def gsub(*a, &b); @string.gsub(*a, &b).chars; end
    
    # Like String.=~ only it returns the character offset (in codepoints) instead of the byte offset.
    def =~(other)
      handler.translate_offset(@string, @string =~ other)
    end
    
    # Try to forward all undefined methods to the handler, when a method is not defined on the handler, send it to
    # the contained string. Method_missing is also responsible for making the bang! methods destructive.
    def method_missing(m, *a, &b)
      begin
        # Simulate methods with a ! at the end because we can't touch the enclosed string from the handlers.
        if m.to_s =~ /^(.*)\!$/ && handler.respond_to?($1)
          result = handler.send($1, @string, *a, &b)
          if result == @string
            result = nil
          else
            @string.replace result
          end
        elsif handler.respond_to?(m)
          result = handler.send(m, @string, *a, &b)
        else
          result = @string.send(m, *a, &b)
        end
      rescue Handlers::EncodingError
        @string.replace handler.tidy_bytes(@string)
        retry
      end
      
      if result.kind_of?(String)
        result.chars
      else
        result
      end
    end
    
    # Set the handler class for the Char objects.
    def self.handler=(klass)
      @@handler = klass
    end

    # Returns the proper handler for the contained string depending on $KCODE and the encoding of the string. This
    # method is used internally to always redirect messages to the proper classes depending on the context.
    def handler
      if utf8_pragma?
        @@handler
      else
        ActiveSupport::Multibyte::Handlers::PassthruHandler
      end
    end

    private
      
      # +utf8_pragma+ checks if it can send this string to the handlers. It makes sure @string isn't nil and $KCODE is
      # set to 'UTF8'.
      if RUBY_VERSION < '1.9'
        def utf8_pragma?
          !@string.nil? && ($KCODE == 'UTF8')
        end
      else
        def utf8_pragma?
          !@string.nil? && (Encoding.default_external == Encoding::UTF_8)
        end
      end
  end
end

# When we can load the utf8proc library, override normalization with the faster methods
begin
  require 'utf8proc_native'
  require 'active_support/multibyte/handlers/utf8_handler_proc'
  ActiveSupport::Multibyte::Chars.handler = ActiveSupport::Multibyte::Handlers::UTF8HandlerProc
rescue LoadError
  ActiveSupport::Multibyte::Chars.handler = ActiveSupport::Multibyte::Handlers::UTF8Handler
end
