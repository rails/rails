module ActiveRecord
  module AttributeMethods
    module Serialization
      extend ActiveSupport::Concern

      CODERS = { # :nodoc:
        json: ActiveRecord::Coders::JSON,
        yaml: ActiveRecord::Coders::YAML
      }.freeze

      module ClassMethods
        # If you have an attribute that needs to be saved to the database as an
        # object, and retrieved as the same object, then specify the name of that
        # attribute using this method and it will be handled automatically.
        #
        # ==== Parameters
        #
        # * +attr_name+ - The field name that should be serialized.
        # * +options+ - Optional, a hash that contains one or more of the
        #   following options.
        #
        # ===== Options
        #
        # [:class_name]
        #   By default, you can store any type of objects in a serialized
        #   column. You can optionally restrict it down to a specific class (and
        #   its subclasses). For example, you can pass +Hash+ here to ensure
        #   only +Hash+ values are allowed. Specifying this option will also
        #   default the attribute to its empty value (e.g. an empty hash if set
        #   to +Hash+). Note that if you specify this option, the coder you
        #   choose must be able to serialiaze and deserialize instances of this
        #   class in both directions.
        #
        # [:coder]
        #   By default, the serialization is done through YAML. You can
        #   customize this behavior by passing a different coder with this
        #   option. Passing +:yaml+ or +:json+ will use the built-in YAML or
        #   JSON coders. If you need more control over how objects are
        #   serialized, you can also pass a custom serializer object that
        #   implments the API described in the next section.
        #
        # ===== Custom Coders
        #
        # If a custom coder object is supplied, it must respond to the following
        # methods:
        #
        # * <tt>deserialize_from_database(raw_data)</tt> - this method will be
        #   passed the serialized data retrived from the database and should
        #   return it in its deserialized form.
        #
        # * <tt>serialize_for_database(value)</tt> - this method will be passed
        #   the deserialized value and should return it in its serialized form
        #   that is suitable for writing to the database.
        #
        # Note that +nil+ values are written directly to the database as +NULL+,
        # therefore your custom coder does not have to explicitly handle null
        # values.
        #
        # For example:
        #
        #   class Base64MarshalCoder
        #     def self.deserialize_from_database(raw_data)
        #       Marshal.load Base64.strict_decode64(raw_data)
        #     end
        #
        #     def self.serialize_for_database(value)
        #       Base64.strict_encode64 Marshal.dump(value)
        #     end
        #   end
        #
        # ==== Example
        #
        #   # Serialize a preferences attribute using the default YAML coder.
        #   class User < ActiveRecord::Base
        #     serialize :preferences
        #   end
        #
        #   # Serialize preferences using JSON as coder.
        #   class User < ActiveRecord::Base
        #     serialize :preferences, coder: :json
        #   end
        #
        #   # Serialize preferences as Hash using the default YAML coder.
        #   class User < ActiveRecord::Base
        #     serialize :preferences, class_name: Hash
        #   end
        #
        #   # It defaults to the empty value of +class_name+ when set.
        #   User.new.preferences # => {}
        def serialize(attr_name, options = {})
          options = convert_legacy_argument_to_options(attr_name, options)
          options.assert_valid_keys(:coder, :class_name)

          coder = lookup_coder(options[:coder])

          if options[:class_name] && options[:class_name] != Object
            coder = ActiveRecord::Coders::Restricted.new(coder, options[:class_name])
          end

          unless is_coder?(coder, false)
            ActiveSupport::Deprecation.warn \
              "Passing a coder implemting the legacy API (`load` and `dump`) is " \
              "deprecated and will not be supported on Rails 5.0. Migrate your " \
              "coder to use the new API or use one of the built-in coders by " \
              "passing `coder: :json` or `coder: :yaml` instead. Refer to the " \
              "documentation for `serialize` for details."

            coder = ActiveRecord::Coders::Legacy.new(coder)
          end

          # The DefaultValue coder also handles nil-guarding
          coder = ActiveRecord::Coders::DefaultValue.new(coder, options[:class_name])

          decorate_attribute_type(attr_name, :serialize) do |type|
            Type::Serialized.new(type, coder)
          end
        end

        def serialized_attributes
          ActiveSupport::Deprecation.warn(<<-WARNING.strip_heredoc)
            `serialized_attributes` is deprecated without replacement, and will
            be removed in Rails 5.0.
          WARNING
          @serialized_attributes ||= Hash[
            columns.select { |t| t.cast_type.is_a?(Type::Serialized) }.map { |c|
              [c.name, c.cast_type.coder]
            }
          ]
        end

        private
          def convert_legacy_argument_to_options(attr_name, arg)
            if arg.is_a?(Hash)
              arg
            elsif arg == ::JSON
              ActiveSupport::Deprecation.warn \
                "Passing a coder as the second argument to `serialize` is " \
                "deprecated, and will be removed in Rails 5.0. Please use " \
                "`serialize #{attr_name.inspect}, coder: :json` instead."

              {coder: :json}
            elsif is_coder?(arg)
              ActiveSupport::Deprecation.warn \
                "Passing a coder as the second argument to `serialize` is " \
                "deprecated, and will be removed in Rails 5.0. Please use " \
                "`serialize #{attr_name.inspect}, coder: MyCoder` instead."

              {coder: arg}
            else
              ActiveSupport::Deprecation.warn \
                "Passing a class name as the second argument to `serialize` " \
                "is deprecated, and will be removed in Rails 5.0. Please use " \
                "`serialize #{attr_name.inspect}, class_name: #{arg.inspect}` " \
                "instead."

              {class_name: arg}
            end
          end

          def lookup_coder(coder)
            if is_coder?(coder)
              coder
            elsif CODERS.key?(coder)
              CODERS[coder]
            elsif coder.nil?
              CODERS[:yaml]
            else
              raise ArgumentError, "Unknown coder #{coder.inspect}"
            end
          end

          def is_coder?(obj, check_legacy = true)
            [:deserialize_from_database, :serialize_for_database].all? { |x| obj.respond_to?(x) } ||
              (check_legacy && is_legacy_coder?(obj))
          end

          def is_legacy_coder?(obj)
            [:load, :dump].all? { |x| obj.respond_to?(x) }
          end
      end
    end
  end
end
