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
    def self.dump(value)
      value.presence.try(:parameterize, "_")
    end

    def self.load(value)
      value.present? ? new(dump(value)) : nil
    end

    def method_missing(method_name, *arguments)
      if method_name[-1, 1] == "?"
        self == method_name[0..-2]
      else
        super
      end
    end
  end
end
