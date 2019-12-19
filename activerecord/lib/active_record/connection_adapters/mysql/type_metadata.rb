# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module MySQL
      class TypeMetadata < DelegateClass(SqlTypeMetadata) # :nodoc:
        undef to_yaml if method_defined?(:to_yaml)

        include Deduplicable

        attr_reader :extra

        def initialize(type_metadata, extra: nil)
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

        private
          def deduplicated
            __setobj__(__getobj__.deduplicate)
            @extra = -extra if extra
            super
          end
      end
    end
  end
end
