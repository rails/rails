module ActiveSupport
  # Wrapping a string in this class gives you a prettier way to test
  # for equality. The value returned by <tt>Rails.env</tt> is wrapped
  # in a StringInquirer object, so instead of calling this:
  #
  #   Rails.env == 'production'
  #
  # you can call this:
  #
  #   Rails.env.production?
  class StringInquirer < String

    def initialize(value, restricted_to: nil)
      super(value)

      if restricted_to
        @restricted_to = restricted_to
        extend RestrictInquiry
      else
        extend LooseInquiry
      end
    end

    module RestrictInquiry
      attr_reader :restricted_to

      private

      def respond_to_missing?(method_name, include_private = false)
        valid_inquiry_method?(method_name) || super
      end

      def method_missing(method_name, *arguments)
        if valid_inquiry_method?(method_name)
          self == method_name[0...-1]
        else
          super
        end
      end

      def valid_inquiry_method?(method_name)
        restricted_to.any? { |e| e.to_s == method_name[0...-1] }
      end
    end

    module LooseInquiry
      private

      def respond_to_missing?(method_name, include_private = false)
        method_name[-1] == '?' || super
      end

      def method_missing(method_name, *arguments)
        if method_name[-1] == '?'
          self == method_name[0...-1]
        else
          super
        end
      end
    end
  end
end
