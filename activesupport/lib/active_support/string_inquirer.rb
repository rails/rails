module ActiveSupport
  # Wrapping a string in this class gives you a prettier way to test
  # for equality. The value returned by <tt>Rails.env</tt> is wrapped
  # in a StringInquirer object so instead of calling this:
  #
  #   Rails.env == 'production'
  #
  # you can call this:
  #
  #   Rails.env.production?
  class StringInquirer < String
    module Strings #:nodoc:
      QUESTION_MARK = '?'.freeze
    end
    private_constant :Strings

    private
      def respond_to_missing?(method_name, include_private = false)
        method_name[-1] == Strings::QUESTION_MARK
      end

      def method_missing(method_name, *arguments)
        if method_name[-1] == Strings::QUESTION_MARK
          self == method_name[0..-2]
        else
          super
        end
      end
  end
end
