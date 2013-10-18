module ActiveSupport
  # Wrapping a string in this class gives you a prettier way to test
  # for equality. The value returned by <tt>Rails.env</tt> is wrapped
  # in a StringInquirer object so instead of calling this:
  #
  #   Rails.env == 'production'
  #   Rails.env != 'production'
  #
  # you can call this:
  #
  #   Rails.env.production?
  #   Rails.env.not.production?
  class StringInquirer < String

      attr_accessor :negated

      def not
        self.dup.tap{ |s| s.negated = !s.negated }
      end

    private

      def respond_to_missing?(method_name, include_private = false)
        method_name[-1] == '?'
      end

      def method_missing(method_name, *arguments)
        if method_name[-1] == '?'
          (self == method_name[0..-2]) ^ self.negated
        else
          super
        end
      end
  end
end
