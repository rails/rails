module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module String #:nodoc:
      # Define methods for handling unicode data.
      module Unicode
        # +chars+ is a Unicode safe proxy for string methods. It creates and returns an instance of the
        # ActiveSupport::Multibyte::Chars class which encapsulates the original string. A Unicode safe version of all
        # the String methods are defined on this proxy class. Undefined methods are forwarded to String, so all of the
        # string overrides can also be called through the +chars+ proxy.
        #
        #   name = 'Claus Müller'
        #   name.reverse #=> "rell??M sualC"
        #   name.length #=> 13
        #
        #   name.chars.reverse.to_s #=> "rellüM sualC"
        #   name.chars.length #=> 12
        #   
        #
        # All the methods on the chars proxy which normally return a string will return a Chars object. This allows
        # method chaining on the result of any of these methods.
        #
        #   name.chars.reverse.length #=> 12
        #
        # The Char object tries to be as interchangeable with String objects as possible: sorting and comparing between
        # String and Char work like expected. The bang! methods change the internal string representation in the Chars
        # object. Interoperability problems can be resolved easily with a +to_s+ call.
        #
        # For more information about the methods defined on the Chars proxy see ActiveSupport::Multibyte::Chars and
        # ActiveSupport::Multibyte::Handlers::UTF8Handler
        def chars
          ActiveSupport::Multibyte::Chars.new(self)
        end

        # Returns true if the string has UTF-8 semantics (a String used for purely byte resources is unlikely to have
        # them), returns false otherwise.
        def is_utf8?
          ActiveSupport::Multibyte::Handlers::UTF8Handler.consumes?(self)
        end
      end
    end
  end
end
