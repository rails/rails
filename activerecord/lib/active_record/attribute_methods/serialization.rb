# frozen_string_literal: true

module ActiveRecord
  module AttributeMethods
    # = Active Record Attribute Methods \Serialization
    module Serialization
      extend ActiveSupport::Concern

      class ColumnNotSerializableError < StandardError
        def initialize(name, type)
          super <<~EOS
            Column `#{name}` of type #{type.class} does not support `serialize` feature.
            Usually it means that you are trying to use `serialize`
            on a column that already implements serialization natively.
          EOS
        end
      end

      included do
        class_attribute :default_column_serializer, instance_accessor: false, default: Coders::YAMLColumn
      end

      module ClassMethods
        # If you have an attribute that needs to be saved to the database as a
        # serialized object, and retrieved by deserializing into the same object,
        # then specify the name of that attribute using this method and serialization
        # will be handled automatically.
        #
        # The serialization format may be YAML, JSON, or any custom format using a
        # custom coder class.
        #
        # Keep in mind that database adapters handle certain serialization tasks
        # for you. For instance: +json+ and +jsonb+ types in PostgreSQL will be
        # converted between JSON object/array syntax and Ruby +Hash+ or +Array+
        # objects transparently. There is no need to use #serialize in this
        # case.
        #
        # For more complex cases, such as conversion to or from your application
        # domain objects, consider using the ActiveRecord::Attributes API.
        #
        # ==== Parameters
        #
        # * +attr_name+ - The name of the attribute to serialize.
        # * +coder+ The serializer implementation to use, e.g. +JSON+.
        #   * The attribute value will be serialized
        #     using the coder's <tt>dump(value)</tt> method, and will be
        #     deserialized using the coder's <tt>load(string)</tt> method. The
        #     +dump+ method may return +nil+ to serialize the value as +NULL+.
        # * +type+ - Optional. What the type of the serialized object should be.
        #   * Attempting to serialize another type will raise an
        #     ActiveRecord::SerializationTypeMismatch error.
        #   * If the column is +NULL+ or starting from a new record, the default value
        #     will set to +type.new+
        # * +yaml+ - Optional. Yaml specific options. The allowed config is:
        #   * +:permitted_classes+ - +Array+ with the permitted classes.
        #   * +:unsafe_load+ - Unsafely load YAML blobs, allow YAML to load any class.
        #
        # ==== Options
        #
        # * +:default+ - The default value to use when no value is provided. If
        #   this option is not passed, the previous default value (if any) will
        #   be used. Otherwise, the default will be +nil+.
        #
        # ==== Choosing a serializer
        #
        # While any serialization format can be used, it is recommended to carefully
        # evaluate the properties of a serializer before using it, as migrating to
        # another format later on can be difficult.
        #
        # ===== Avoid accepting arbitrary types
        #
        # When serializing data in a column, it is heavily recommended to make sure
        # only expected types will be serialized. For instance some serializer like
        # +Marshal+ or +YAML+ are capable of serializing almost any Ruby object.
        #
        # This can lead to unexpected types being serialized, and it is important
        # that type serialization remains backward and forward compatible as long
        # as some database records still contain these serialized types.
        #
        #   class Address
        #     def initialize(line, city, country)
        #       @line, @city, @country = line, city, country
        #     end
        #   end
        #
        # In the above example, if any of the +Address+ attributes is renamed,
        # instances that were persisted before the change will be loaded with the
        # old attributes. This problem is even worse when the serialized type comes
        # from a dependency which doesn't expect to be serialized this way and may
        # change its internal representation without notice.
        #
        # As such, it is heavily recommended to instead convert these objects into
        # primitives of the serialization format, for example:
        #
        #   class Address
        #     attr_reader :line, :city, :country
        #
        #     def self.load(payload)
        #       data = YAML.safe_load(payload)
        #       new(data["line"], data["city"], data["country"])
        #     end
        #
        #     def self.dump(address)
        #       YAML.safe_dump(
        #         "line" => address.line,
        #         "city" => address.city,
        #         "country" => address.country,
        #       )
        #     end
        #
        #     def initialize(line, city, country)
        #       @line, @city, @country = line, city, country
        #     end
        #   end
        #
        #   class User < ActiveRecord::Base
        #     serialize :address, coder: Address
        #   end
        #
        # This pattern allows to be more deliberate about what is serialized, and
        # to evolve the format in a backward compatible way.
        #
        # ===== Ensure serialization stability
        #
        # Some serialization methods may accept some types they don't support by
        # silently casting them to other types. This can cause bugs when the
        # data is deserialized.
        #
        # For instance the +JSON+ serializer provided in the standard library will
        # silently cast unsupported types to +String+:
        #
        #   >> JSON.parse(JSON.dump(Struct.new(:foo)))
        #   => "#<Class:0x000000013090b4c0>"
        #
        # ==== Examples
        #
        # ===== Serialize the +preferences+ attribute using YAML
        #
        #   class User < ActiveRecord::Base
        #     serialize :preferences, coder: YAML
        #   end
        #
        # ===== Serialize the +preferences+ attribute using JSON
        #
        #   class User < ActiveRecord::Base
        #     serialize :preferences, coder: JSON
        #   end
        #
        # ===== Serialize the +preferences+ +Hash+ using YAML
        #
        #   class User < ActiveRecord::Base
        #     serialize :preferences, type: Hash, coder: YAML
        #   end
        #
        # ===== Serializes +preferences+ to YAML, permitting select classes
        #
        #   class User < ActiveRecord::Base
        #     serialize :preferences, coder: YAML, yaml: { permitted_classes: [Symbol, Time] }
        #   end
        #
        # ===== Serialize the +preferences+ attribute using a custom coder
        #
        #   class Rot13JSON
        #     def self.rot13(string)
        #       string.tr("a-zA-Z", "n-za-mN-ZA-M")
        #     end
        #
        #     # Serializes an attribute value to a string that will be stored in the database.
        #     def self.dump(value)
        #       rot13(ActiveSupport::JSON.dump(value))
        #     end
        #
        #     # Deserializes a string from the database to an attribute value.
        #     def self.load(string)
        #       ActiveSupport::JSON.load(rot13(string))
        #     end
        #   end
        #
        #   class User < ActiveRecord::Base
        #     serialize :preferences, coder: Rot13JSON
        #   end
        #
        def serialize(attr_name, coder: nil, type: Object, yaml: {}, **options)
          coder ||= default_column_serializer
          unless coder
            raise ArgumentError, <<~MSG.squish
              missing keyword: :coder

              If no default coder is configured, a coder must be provided to `serialize`.
            MSG
          end

          column_serializer = build_column_serializer(attr_name, coder, type, yaml)

          attribute(attr_name, **options)

          decorate_attributes([attr_name]) do |attr_name, cast_type|
            if type_incompatible_with_serialize?(cast_type, coder, type)
              raise ColumnNotSerializableError.new(attr_name, cast_type)
            end

            cast_type = cast_type.subtype if Type::Serialized === cast_type
            Type::Serialized.new(cast_type, column_serializer)
          end
        end

        private
          def build_column_serializer(attr_name, coder, type, yaml = nil)
            # When ::JSON is used, force it to go through the Active Support JSON encoder
            # to ensure special objects (e.g. Active Record models) are dumped correctly
            # using the #as_json hook.
            coder = Coders::JSON if coder == ::JSON

            if coder == ::YAML || coder == Coders::YAMLColumn
              Coders::YAMLColumn.new(attr_name, type, **(yaml || {}))
            elsif coder.respond_to?(:new) && !coder.respond_to?(:load)
              coder.new(attr_name, type)
            elsif type && type != Object
              Coders::ColumnSerializer.new(attr_name, coder, type)
            else
              coder
            end
          end

          def type_incompatible_with_serialize?(cast_type, coder, type)
            cast_type.is_a?(ActiveRecord::Type::Json) && coder == ::JSON ||
              cast_type.respond_to?(:type_cast_array, true) && type == ::Array
          end
      end
    end
  end
end
