module DateAndTime
  module Formatting #:nodoc:
    def apply_formatting(format = :default)
      if formatter = self.class::DATE_FORMATS[format]
        if formatter.respond_to?(:call)
          formatter.call(self).to_s
        else
          strftime(formatter)
        end
      else
        to_default_s
      end
    end
  end
end
