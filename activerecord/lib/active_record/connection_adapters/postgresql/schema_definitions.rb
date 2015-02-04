module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module ColumnMethods
        def xml(*args)
          options = args.extract_options!
          column(args[0], :xml, options)
        end

        def tsvector(*args)
          options = args.extract_options!
          column(args[0], :tsvector, options)
        end

        def int4range(name, options = {})
          column(name, :int4range, options)
        end

        def int8range(name, options = {})
          column(name, :int8range, options)
        end

        def tsrange(name, options = {})
          column(name, :tsrange, options)
        end

        def tstzrange(name, options = {})
          column(name, :tstzrange, options)
        end

        def numrange(name, options = {})
          column(name, :numrange, options)
        end

        def daterange(name, options = {})
          column(name, :daterange, options)
        end

        def hstore(name, options = {})
          column(name, :hstore, options)
        end

        def ltree(name, options = {})
          column(name, :ltree, options)
        end

        def inet(name, options = {})
          column(name, :inet, options)
        end

        def cidr(name, options = {})
          column(name, :cidr, options)
        end

        def macaddr(name, options = {})
          column(name, :macaddr, options)
        end

        def uuid(name, options = {})
          column(name, :uuid, options)
        end

        def json(name, options = {})
          column(name, :json, options)
        end

        def jsonb(name, options = {})
          column(name, :jsonb, options)
        end

        def citext(name, options = {})
          column(name, :citext, options)
        end

        def point(name, options = {})
          column(name, :point, options)
        end

        def bit(name, options = {})
          column(name, :bit, options)
        end

        def bit_varying(name, options = {})
          column(name, :bit_varying, options)
        end

        def money(name, options = {})
          column(name, :money, options)
        end
      end

      class ColumnDefinition < ActiveRecord::ConnectionAdapters::ColumnDefinition
        attr_accessor :array
      end

      class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
        include ColumnMethods

        # Defines the primary key field.
        # Use of the native PostgreSQL UUID type is supported, and can be used
        # by defining your tables as such:
        #
        #   create_table :stuffs, id: :uuid do |t|
        #     t.string :content
        #     t.timestamps
        #   end
        #
        # By default, this will use the +uuid_generate_v4()+ function from the
        # +uuid-ossp+ extension, which MUST be enabled on your database. To enable
        # the +uuid-ossp+ extension, you can use the +enable_extension+ method in your
        # migrations. To use a UUID primary key without +uuid-ossp+ enabled, you can
        # set the +:default+ option to +nil+:
        #
        #   create_table :stuffs, id: false do |t|
        #     t.primary_key :id, :uuid, default: nil
        #     t.uuid :foo_id
        #     t.timestamps
        #   end
        #
        # You may also pass a different UUID generation function from +uuid-ossp+
        # or another library.
        #
        # Note that setting the UUID primary key default value to +nil+ will
        # require you to assure that you always provide a UUID value before saving
        # a record (as primary keys cannot be +nil+). This might be done via the
        # +SecureRandom.uuid+ method and a +before_save+ callback, for instance.
        def primary_key(name, type = :primary_key, options = {})
          return super unless type == :uuid
          options[:default] = options.fetch(:default, 'uuid_generate_v4()')
          options[:primary_key] = true
          column name, type, options
        end

        def new_column_definition(name, type, options) # :nodoc:
          column = super
          column.array = options[:array]
          column
        end

        private

          def create_column_definition(name, type)
            PostgreSQL::ColumnDefinition.new name, type
          end
      end

      class Table < ActiveRecord::ConnectionAdapters::Table
        include ColumnMethods
      end
    end
  end
end
