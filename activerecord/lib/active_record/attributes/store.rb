module ActiveRecord
  module Attributes
    class Store < Hash
      include ActiveRecord::Attributes::Typecasting
      include ActiveRecord::Attributes::Aliasing

      # Attributes not mapped to a column are handled using Type::Unknown,
      # which enables boolean typecasting for unmapped keys.
      def types
        @types ||= Hash.new(Type::Unknown.new)
      end

    end
  end
end
