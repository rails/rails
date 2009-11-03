module ActiveRecord
  module Type
    module Casting

       def cast(value)
         typecaster.type_cast(value)
       end

       def precast(value)
         value
       end

       def boolean(value)
         cast(value).present?
       end

       # Attributes::Typecasting stores appendable? types (e.g. serialized Arrays) when typecasting reads.
       def appendable?
         false
       end

    end

    class Object
      include Casting

      attr_reader :name, :options
      attr_reader :typecaster

      def initialize(typecaster = nil, options = {})
        @typecaster, @options = typecaster, options
      end

    end

  end
end