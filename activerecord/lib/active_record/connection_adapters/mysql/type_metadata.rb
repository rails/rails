module ActiveRecord
  module ConnectionAdapters
    module MySQL
      class TypeMetadata < DelegateClass(SqlTypeMetadata) # :nodoc:
        attr_reader :extra, :strict

        def initialize(type_metadata, extra: "", strict: false)
          super(type_metadata)
          @type_metadata = type_metadata
          @extra = extra
          @strict = strict
        end

        def ==(other)
          other.is_a?(MySQL::TypeMetadata) &&
            attributes_for_hash == other.attributes_for_hash
        end
        alias eql? ==

        def hash
          attributes_for_hash.hash
        end

        protected

        def attributes_for_hash
          [self.class, @type_metadata, extra, strict]
        end
      end
    end
  end
end
