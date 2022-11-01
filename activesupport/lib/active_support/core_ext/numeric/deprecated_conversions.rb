# frozen_string_literal: true

module ActiveSupport
  module DeprecatedNumericWithFormat # :nodoc:
    def to_s(format = nil, options = nil)
      return super() if format.nil?

      case format
      when Integer, String
        super(format)
      when :phone
        ActiveSupport.deprecator.warn(
          "#{self.class}#to_s(#{format.inspect}) is deprecated. Please use #{self.class}#to_fs(#{format.inspect}) instead."
        )
        ActiveSupport::NumberHelper.number_to_phone(self, options || {})
      when :currency
        ActiveSupport.deprecator.warn(
          "#{self.class}#to_s(#{format.inspect}) is deprecated. Please use #{self.class}#to_fs(#{format.inspect}) instead."
        )
        ActiveSupport::NumberHelper.number_to_currency(self, options || {})
      when :percentage
        ActiveSupport.deprecator.warn(
          "#{self.class}#to_s(#{format.inspect}) is deprecated. Please use #{self.class}#to_fs(#{format.inspect}) instead."
        )
        ActiveSupport::NumberHelper.number_to_percentage(self, options || {})
      when :delimited
        ActiveSupport.deprecator.warn(
          "#{self.class}#to_s(#{format.inspect}) is deprecated. Please use #{self.class}#to_fs(#{format.inspect}) instead."
        )
        ActiveSupport::NumberHelper.number_to_delimited(self, options || {})
      when :rounded
        ActiveSupport.deprecator.warn(
          "#{self.class}#to_s(#{format.inspect}) is deprecated. Please use #{self.class}#to_fs(#{format.inspect}) instead."
        )
        ActiveSupport::NumberHelper.number_to_rounded(self, options || {})
      when :human
        ActiveSupport.deprecator.warn(
          "#{self.class}#to_s(#{format.inspect}) is deprecated. Please use #{self.class}#to_fs(#{format.inspect}) instead."
        )
        ActiveSupport::NumberHelper.number_to_human(self, options || {})
      when :human_size
        ActiveSupport.deprecator.warn(
          "#{self.class}#to_s(#{format.inspect}) is deprecated. Please use #{self.class}#to_fs(#{format.inspect}) instead."
        )
        ActiveSupport::NumberHelper.number_to_human_size(self, options || {})
      when Symbol
        ActiveSupport.deprecator.warn(
          "#{self.class}#to_s(#{format.inspect}) is deprecated. Please use #{self.class}#to_fs(#{format.inspect}) instead."
        )
        super()
      else
        super(format)
      end
    end
  end
end

Integer.prepend ActiveSupport::DeprecatedNumericWithFormat
Float.prepend ActiveSupport::DeprecatedNumericWithFormat
BigDecimal.prepend ActiveSupport::DeprecatedNumericWithFormat
