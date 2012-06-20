module ActiveSupport
  # Wrapping a string in this class gives you a prettier way to test
  # for equality. The value returned by <tt>Rails.env</tt> is wrapped
  # in a StringInquirer object so instead of calling this:
  #
  #   Rails.env == "production"
  #
  # you can call this:
  #
  #   Rails.env.production?
  #
  class StringInquirer < String
    def method_missing(method_name, *arguments)
      if method_name[-1, 1] == "?"
        is_eql_to_self = (self == method_name[0..-2])
        define_singleton_method(method_name) { is_eql_to_self }
        is_eql_to_self
      else
        super
      end
    end
  end
end
