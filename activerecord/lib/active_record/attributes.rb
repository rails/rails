module ActiveRecord
  module Attributes # :nodoc:
    extend ActiveSupport::Concern

    Type = ActiveRecord::Type

    included do
      class_attribute :attributes_to_define_after_schema_loads, instance_accessor: false # :internal:
      self.attributes_to_define_after_schema_loads = {}
    end

    module ClassMethods # :nodoc:
      # Defines or overrides an attribute on this model. This allows customization of
      # Active Record's type casting behavior, as well as adding support for user defined
      # types.
      #
      # +name+ The name of the methods to define attribute methods for, and the column which
      # this will persist to.
      #
      # +cast_type+ A type object that contains information about how to type cast the value.
      # See the examples section for more information.
      #
      # ==== Options
      # The options hash accepts the following options:
      #
      # +default+ is the default value that the column should use on a new record.
      #
      # ==== Examples
      #
      # The type detected by Active Record can be overridden.
      #
      #   # db/schema.rb
      #   create_table :store_listings, force: true do |t|
      #     t.decimal :price_in_cents
      #   end
      #
      #   # app/models/store_listing.rb
      #   class StoreListing < ActiveRecord::Base
      #   end
      #
      #   store_listing = StoreListing.new(price_in_cents: '10.1')
      #
      #   # before
      #   store_listing.price_in_cents # => BigDecimal.new(10.1)
      #
      #   class StoreListing < ActiveRecord::Base
      #     attribute :price_in_cents, Type::Integer.new
      #   end
      #
      #   # after
      #   store_listing.price_in_cents # => 10
      #
      # Users may also define their own custom types, as long as they respond to the methods
      # defined on the value type. The +type_cast+ method on your type object will be called
      # with values both from the database, and from your controllers. See
      # +ActiveRecord::Attributes::Type::Value+ for the expected API. It is recommended that your
      # type objects inherit from an existing type, or the base value type.
      #
      #   class MoneyType < ActiveRecord::Type::Integer
      #     def type_cast(value)
      #       if value.include?('$')
      #         price_in_dollars = value.gsub(/\$/, '').to_f
      #         price_in_dollars * 100
      #       else
      #         value.to_i
      #       end
      #     end
      #   end
      #
      #   class StoreListing < ActiveRecord::Base
      #     attribute :price_in_cents, MoneyType.new
      #   end
      #
      #   store_listing = StoreListing.new(price_in_cents: '$10.00')
      #   store_listing.price_in_cents # => 1000
      def attribute(name, cast_type, **options)
        name = name.to_s
        reload_schema_from_cache

        self.attributes_to_define_after_schema_loads = attributes_to_define_after_schema_loads.merge(name => [cast_type, options])
      end

      def define_attribute(
        name,
        cast_type,
        default: NO_DEFAULT_PROVIDED,
        user_provided_default: true
      )
        attribute_types[name] = cast_type
        define_default_attribute(name, default, cast_type, from_user: user_provided_default)
      end

      def load_schema!
        super
        attributes_to_define_after_schema_loads.each do |name, (type, options)|
          define_attribute(name, type, **options)
        end
      end

      private

      NO_DEFAULT_PROVIDED = Object.new # :nodoc:
      private_constant :NO_DEFAULT_PROVIDED

      def define_default_attribute(name, value, type, from_user:)
        if value == NO_DEFAULT_PROVIDED
          default_attribute = _default_attributes[name].with_type(type)
        elsif from_user
          default_attribute = Attribute.from_user(name, value, type)
        else
          default_attribute = Attribute.from_database(name, value, type)
        end
        _default_attributes[name] = default_attribute
      end
    end
  end
end
