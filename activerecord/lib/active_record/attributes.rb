# frozen_string_literal: true

require "active_model/attribute/user_provided_default"

module ActiveRecord
  # See ActiveRecord::Attributes::ClassMethods for documentation
  module Attributes
    extend ActiveSupport::Concern

    included do
      class_attribute :attributes_to_define_after_schema_loads, instance_accessor: false, default: {} # :internal:
    end

    module ClassMethods
      # Defines an attribute with a type on this model. It will override the
      # type of existing attributes if needed. This allows control over how
      # values are converted to and from SQL when assigned to a model. It also
      # changes the behavior of values passed to
      # {ActiveRecord::Base.where}[rdoc-ref:QueryMethods#where]. This will let you use
      # your domain objects across much of Active Record, without having to
      # rely on implementation details or monkey patching.
      #
      # +name+ The name of the methods to define attribute methods for, and the
      # column which this will persist to.
      #
      # +cast_type+ A symbol such as +:string+ or +:integer+, or a type object
      # to be used for this attribute. See the examples below for more
      # information about providing custom type objects.
      #
      # ==== Options
      #
      # The following options are accepted:
      #
      # +default+ The default value to use when no value is provided. If this option
      # is not passed, the previous default value (if any) will be used.
      # Otherwise, the default will be +nil+.
      #
      # +array+ (PostgreSQL only) specifies that the type should be an array (see the
      # examples below).
      #
      # +range+ (PostgreSQL only) specifies that the type should be a range (see the
      # examples below).
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
      #   store_listing.price_in_cents # => BigDecimal(10.1)
      #
      #   class StoreListing < ActiveRecord::Base
      #     attribute :price_in_cents, :integer
      #   end
      #
      #   # after
      #   store_listing.price_in_cents # => 10
      #
      # A default can also be provided.
      #
      #   # db/schema.rb
      #   create_table :store_listings, force: true do |t|
      #     t.string :my_string, default: "original default"
      #   end
      #
      #   StoreListing.new.my_string # => "original default"
      #
      #   # app/models/store_listing.rb
      #   class StoreListing < ActiveRecord::Base
      #     attribute :my_string, :string, default: "new default"
      #   end
      #
      #   StoreListing.new.my_string # => "new default"
      #
      #   class Product < ActiveRecord::Base
      #     attribute :my_default_proc, :datetime, default: -> { Time.now }
      #   end
      #
      #   Product.new.my_default_proc # => 2015-05-30 11:04:48 -0600
      #   sleep 1
      #   Product.new.my_default_proc # => 2015-05-30 11:04:49 -0600
      #
      # \Attributes do not need to be backed by a database column.
      #
      #   # app/models/my_model.rb
      #   class MyModel < ActiveRecord::Base
      #     attribute :my_string, :string
      #     attribute :my_int_array, :integer, array: true
      #     attribute :my_float_range, :float, range: true
      #   end
      #
      #   model = MyModel.new(
      #     my_string: "string",
      #     my_int_array: ["1", "2", "3"],
      #     my_float_range: "[1,3.5]",
      #   )
      #   model.attributes
      #   # =>
      #     {
      #       my_string: "string",
      #       my_int_array: [1, 2, 3],
      #       my_float_range: 1.0..3.5
      #     }
      #
      # ==== Creating Custom Types
      #
      # Users may also define their own custom types, as long as they respond
      # to the methods defined on the value type. The method +deserialize+ or
      # +cast+ will be called on your type object, with raw input from the
      # database or from your controllers. See ActiveModel::Type::Value for the
      # expected API. It is recommended that your type objects inherit from an
      # existing type, or from ActiveRecord::Type::Value
      #
      #   class MoneyType < ActiveRecord::Type::Integer
      #     def cast(value)
      #       if !value.kind_of?(Numeric) && value.include?('$')
      #         price_in_dollars = value.gsub(/\$/, '').to_f
      #         super(price_in_dollars * 100)
      #       else
      #         super
      #       end
      #     end
      #   end
      # #
      #   # app/models/store_listing.rb
      #   class StoreListing < ActiveRecord::Base
      #     attribute :price_in_cents, MoneyType.new
      #   end
      #
      #   store_listing = StoreListing.new(price_in_cents: '$10.00')
      #   store_listing.price_in_cents # => 1000
      #
      # For more details on creating custom types, see the documentation for
      # ActiveRecord::Type::Value.
      #
      # It is also possible to register a type within an initializer. It is then possible to use a symbol to refer to
      # the type rather than passing an instantiated type directly within attribute:
      #
      #   # config/initializers/types.rb
      #   require 'lib/money_type' # NB: don't use an autoloaded location from initializers
      #   ActiveRecord::Type.register(:money, MoneyType)
      #
      #   # app/models/store_listing.rb
      #   class StoreListing < ActiveRecord::Base
      #     attribute :price_in_cents, :money
      #   end
      #
      # see ActiveRecord::Type.register for more details

      #
      # ==== \Querying
      #
      # When {ActiveRecord::Base.where}[rdoc-ref:QueryMethods#where] is called, it will
      # use the type defined by the model class to convert the value to SQL,
      # calling +serialize+ on your type object. For example:
      #
      #   class Money < Struct.new(:amount, :currency)
      #   end
      #
      #   class MoneyType < Type::Value
      #     def initialize(currency_converter:)
      #       @currency_converter = currency_converter
      #     end
      #
      #     # value will be the result of +deserialize+ or
      #     # +cast+. Assumed to be an instance of +Money+ in
      #     # this case.
      #     def serialize(value)
      #       value_in_bitcoins = @currency_converter.convert_to_bitcoins(value)
      #       value_in_bitcoins.amount
      #     end
      #   end
      #
      #   # config/initializers/types.rb
      #   ActiveRecord::Type.register(:money, MoneyType)
      #
      #   # app/models/product.rb
      #   class Product < ActiveRecord::Base
      #     currency_converter = ConversionRatesFromTheInternet.new
      #     attribute :price_in_bitcoins, :money, currency_converter: currency_converter
      #   end
      #
      #   Product.where(price_in_bitcoins: Money.new(5, "USD"))
      #   # => SELECT * FROM products WHERE price_in_bitcoins = 0.02230
      #
      #   Product.where(price_in_bitcoins: Money.new(5, "GBP"))
      #   # => SELECT * FROM products WHERE price_in_bitcoins = 0.03412
      #
      # ==== Dirty Tracking
      #
      # The type of an attribute is given the opportunity to change how dirty
      # tracking is performed. The methods +changed?+ and +changed_in_place?+
      # will be called from ActiveModel::Dirty. See the documentation for those
      # methods in ActiveModel::Type::Value for more details.
      def attribute(name, cast_type = Type::Value.new, **options)
        name = name.to_s
        reload_schema_from_cache

        self.attributes_to_define_after_schema_loads =
          attributes_to_define_after_schema_loads.merge(
            name => [cast_type, options]
          )
      end

      # This is the low level API which sits beneath +attribute+. It only
      # accepts type objects, and will do its work immediately instead of
      # waiting for the schema to load. Automatic schema detection and
      # ClassMethods#attribute both call this under the hood. While this method
      # is provided so it can be used by plugin authors, application code
      # should probably use ClassMethods#attribute.
      #
      # +name+ The name of the attribute being defined. Expected to be a +String+.
      #
      # +cast_type+ The type object to use for this attribute.
      #
      # +default+ The default value to use when no value is provided. If this option
      # is not passed, the previous default value (if any) will be used.
      # Otherwise, the default will be +nil+. A proc can also be passed, and
      # will be called once each time a new value is needed.
      #
      # +user_provided_default+ Whether the default value should be cast using
      # +cast+ or +deserialize+.
      def define_attribute(
        name,
        cast_type,
        default: NO_DEFAULT_PROVIDED,
        user_provided_default: true
      )
        attribute_types[name] = cast_type
        define_default_attribute(name, default, cast_type, from_user: user_provided_default)
      end

      def load_schema! # :nodoc:
        super
        attributes_to_define_after_schema_loads.each do |name, (type, options)|
          if type.is_a?(Symbol)
            type = ActiveRecord::Type.lookup(type, **options.except(:default))
          end

          define_attribute(name, type, **options.slice(:default))
        end
      end

      private

        NO_DEFAULT_PROVIDED = Object.new # :nodoc:
        private_constant :NO_DEFAULT_PROVIDED

        def define_default_attribute(name, value, type, from_user:)
          if value == NO_DEFAULT_PROVIDED
            default_attribute = _default_attributes[name].with_type(type)
          elsif from_user
            default_attribute = ActiveModel::Attribute::UserProvidedDefault.new(
              name,
              value,
              type,
              _default_attributes.fetch(name.to_s) { nil },
            )
          else
            default_attribute = ActiveModel::Attribute.from_database(name, value, type)
          end
          _default_attributes[name] = default_attribute
        end
    end
  end
end
