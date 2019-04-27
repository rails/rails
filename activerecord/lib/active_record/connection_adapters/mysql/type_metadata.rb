# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module MySQL
      class TypeMetadata < DelegateClass(SqlTypeMetadata) # :nodoc:
        undef to_yaml if method_defined?(:to_yaml)

        attr_reader :extra

        def initialize(type_metadata, extra: "")
          super(type_metadata)
          @extra = extra
        end

        def ==(other)
          other.is_a?(TypeMetadata) &&
            __getobj__ == other.__getobj__ &&
            extra == other.extra
        end
        alias eql? ==

        def hash
          TypeMetadata.hash ^
            __getobj__.hash ^
            extra.hash
        end
      end
    end
  end
end
