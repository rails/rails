module ActiveRecord
  module ConnectionAdapters
    module Type
      extend ActiveSupport::Autoload

      autoload :Binary
      autoload :Boolean
      autoload :Date
      autoload :DateTime
      autoload :Decimal
      autoload :Float
      autoload :Integer
      autoload :Numeric
      autoload :String
      autoload :Text
      autoload :Time
      autoload :TimeValue
      autoload :Timestamp
      autoload :TypeMapping
      autoload :Value
    end
  end
end
