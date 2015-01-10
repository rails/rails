module ActiveRecord
  module Attributes # :nodoc:
    extend ActiveSupport::Concern

    Type = ActiveRecord::Type

    included do
      class_attribute :user_provided_columns, instance_accessor: false # :internal:
      class_attribute :user_provided_defaults, instance_accessor: false # :internal:
      self.user_provided_columns = {}
      self.user_provided_defaults = {}

      delegate :persistable_attribute_names, to: :class
    end

    module ClassMethods # :nodoc:
      # Defines or overrides a attribute on this model. This allows customization of
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
      # defined on the value type. The `type_cast` method on your type object will be called
      # with values both from the database, and from your controllers. See
      # `ActiveRecord::Attributes::Type::Value` for the expected API. It is recommended that your
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
      def attribute(name, cast_type, options = {})
        name = name.to_s
        clear_caches_calculated_from_columns
        # Assign a new hash to ensure that subclasses do not share a hash
        self.user_provided_columns = user_provided_columns.merge(name => cast_type)

        if options.key?(:default)
          self.user_provided_defaults = user_provided_defaults.merge(name => options[:default])
        end
      end

      # Returns an array of column objects for the table associated with this class.
      def columns
        @columns ||= add_user_provided_columns(connection.schema_cache.columns(table_name))
      end

      # Returns a hash of column objects for the table associated with this class.
      def columns_hash
        @columns_hash ||= Hash[columns.map { |c| [c.name, c] }]
      end

      def persistable_attribute_names # :nodoc:
        @persistable_attribute_names ||= connection.schema_cache.columns_hash(table_name).keys
      end

      def reset_column_information # :nodoc:
        super
        clear_caches_calculated_from_columns
      end

      private

      def add_user_provided_columns(schema_columns)
        existing_columns = schema_columns.map do |column|
          new_type = user_provided_columns[column.name]
          if new_type
            column.with_type(new_type)
          else
            column
          end
        end

        existing_column_names = existing_columns.map(&:name)
        new_columns = user_provided_columns.except(*existing_column_names).map do |(name, type)|
          connection.new_column(name, nil, type)
        end

        existing_columns + new_columns
      end

      def clear_caches_calculated_from_columns
        @attributes_builder = nil
        @column_names = nil
        @column_types = nil
        @columns = nil
        @columns_hash = nil
        @content_columns = nil
        @default_attributes = nil
        @persistable_attribute_names = nil
      end

      def raw_default_values
        super.merge(user_provided_defaults)
      end
    end
  end
end
