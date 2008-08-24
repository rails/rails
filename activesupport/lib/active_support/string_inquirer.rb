module ActiveSupport
  class StringInquirer < String
    def method_missing(method_name, *arguments)
      if method_name.to_s.ends_with?("?")
        self == method_name.to_s[0..-2]
      else
        super
      end
    end
  end
end
