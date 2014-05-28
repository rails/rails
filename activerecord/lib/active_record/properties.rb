module ActiveRecord
  module Properties # :nodoc:
    extend ActiveSupport::Concern

    Type = ActiveRecord::Type

    included do
      class_attribute :user_provided_columns, instance_accessor: false # :internal
      self.user_provided_columns = {}
    end

    module ClassMethods
      # Defines or overrides a property on this model. This allows customization of
      # Active Record's type casting behavior, as well as adding support for user defined
      # types.
      #
      # ==== Examples
      #
      # The type detected by Active Record can be overriden.
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
      #     property :price_in_cents, Type::Integer.new
      #   end
      #
      #   # after
      #   store_listing.price_in_cents # => 10
      #
      # Users may also define their own custom types, as long as they respond to the methods
      # defined on the value type. The `type_cast` method on your type object will be called
      # with values both from the database, and from your controllers. See
      # `ActiveRecord::Properties::Type::Value` for the expected API. It is recommended that your
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
      #     property :price_in_cents, MoneyType.new
      #   end
      #
      #   store_listing = StoreListing.new(price_in_cents: '$10.00')
      #   store_listing.price_in_cents # => 1000
      def property(name, cast_type)
        name = name.to_s
        clear_properties_cache
        # Assign a new hash to ensure that subclasses do not share a hash
        self.user_provided_columns = user_provided_columns.merge(name => connection.new_column(name, nil, cast_type))
      end

      # Returns an array of column objects for the table associated with this class.
      def columns
        @columns ||= add_user_provided_columns(connection.schema_cache.columns(table_name))
      end

      # Returns a hash of column objects for the table associated with this class.
      def columns_hash
        @columns_hash ||= Hash[columns.map { |c| [c.name, c] }]
      end

      def reset_column_information # :nodoc:
        super
        clear_properties_cache
      end

      private

      def add_user_provided_columns(schema_columns)
        existing_columns = schema_columns.map do |column|
          user_provided_columns[column.name] || column
        end

        existing_column_names = existing_columns.map(&:name)
        new_columns = user_provided_columns.except(*existing_column_names).values

        existing_columns + new_columns
      end

      def clear_properties_cache
        @columns = nil
        @columns_hash = nil
      end
    end
  end
end
