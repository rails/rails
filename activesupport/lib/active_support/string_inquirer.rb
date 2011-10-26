require 'active_support/core_ext/object/inclusion'

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
      if method_name.to_s[-1, 1] == "?"
        s = method_name.to_s[0..-2]
        return true if self == s
        return false unless s.include?('_or_')
        return true if s.include?('_or_or_or_') || s.start_with?('or_or_') || s.end_with?('_or_or')
        self.in?(s.split('_or_'))
      else
        super
      end
    end
  end
end
