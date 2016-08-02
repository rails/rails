module ActiveSupport
  # Wrapping a string in this class gives you a prettier way to test
  # for equality.
  # It overrides method_missing to respond to every predicate methods called on
  # it, evaluating each time if method name is equal to value of StringInquirer
  # object on which predicate method was called.
  #
  # vehicle = ActiveSupport::StringInquirer.new('car')
  #
  # vehicle.car?   => true
  # vehicle.bike?  => false
  #
  # The value returned by <tt>Rails.env</tt> is wrapped
  # in a StringInquirer object, so instead of calling this:
  #
  # Rails.env == 'production'
  #
  # you can call this:
  #
  # Rails.env.production?
  class StringInquirer < String
    private

      def respond_to_missing?(method_name, include_private = false)
        method_name[-1] == '?'
      end

      def method_missing(method_name, *arguments)
        if method_name[-1] == '?'
          self == method_name[0..-2]
        else
          super
        end
      end
  end
end
