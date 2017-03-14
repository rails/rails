module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module ColumnMethods
        # Defines the primary key field.
        # Use of the native PostgreSQL UUID type is supported, and can be used
        # by defining your tables as such:
        #
        #   create_table :stuffs, id: :uuid do |t|
        #     t.string :content
        #     t.timestamps
        #   end
        #
        # By default, this will use the +gen_random_uuid()+ function from the
        # +pgcrypto+ extension. As that extension is only available in
        # PostgreSQL 9.4+, for earlier versions an explicit default can be set
        # to use +uuid_generate_v4()+ from the +uuid-ossp+ extension instead:
        #
        #   create_table :stuffs, id: false do |t|
        #     t.primary_key :id, :uuid, default: "uuid_generate_v4()"
        #     t.uuid :foo_id
        #     t.timestamps
        #   end
        #
        # To enable the appropriate extension, which is a requirement, use
        # the +enable_extension+ method in your migrations.
        #
        # To use a UUID primary key without any of the extensions, set the
        # +:default+ option to +nil+:
        #
        #   create_table :stuffs, id: false do |t|
        #     t.primary_key :id, :uuid, default: nil
        #     t.uuid :foo_id
        #     t.timestamps
        #   end
        #
        # You may also pass a custom stored procedure that returns a UUID or use a
        # different UUID generation function from another library.
        #
        # Note that setting the UUID primary key default value to +nil+ will
        # require you to assure that you always provide a UUID value before saving
        # a record (as primary keys cannot be +nil+). This might be done via the
        # +SecureRandom.uuid+ method and a +before_save+ callback, for instance.
        def primary_key(name, type = :primary_key, **options)
          options[:auto_increment] = true if [:integer, :bigint].include?(type) && !options.key?(:default)
          if type == :uuid
            options[:default] = options.fetch(:default, "gen_random_uuid()")
          elsif options.delete(:auto_increment) == true && %i(integer bigint).include?(type)
            type = if type == :bigint || options[:limit] == 8
              :bigserial
            else
              :serial
            end
          end

          super
        end

        def bigserial(*args, **options)
          args.each { |name| column(name, :bigserial, options) }
        end

        def bit(*args, **options)
          args.each { |name| column(name, :bit, options) }
        end

        def bit_varying(*args, **options)
          args.each { |name| column(name, :bit_varying, options) }
        end

        def cidr(*args, **options)
          args.each { |name| column(name, :cidr, options) }
        end

        def citext(*args, **options)
          args.each { |name| column(name, :citext, options) }
        end

        def daterange(*args, **options)
          args.each { |name| column(name, :daterange, options) }
        end

        def hstore(*args, **options)
          args.each { |name| column(name, :hstore, options) }
        end

        def inet(*args, **options)
          args.each { |name| column(name, :inet, options) }
        end

        def interval(*args, **options)
          args.each { |name| column(name, :interval, options) }
        end

        def int4range(*args, **options)
          args.each { |name| column(name, :int4range, options) }
        end

        def int8range(*args, **options)
          args.each { |name| column(name, :int8range, options) }
        end

        def json(*args, **options)
          args.each { |name| column(name, :json, options) }
        end

        def jsonb(*args, **options)
          args.each { |name| column(name, :jsonb, options) }
        end

        def ltree(*args, **options)
          args.each { |name| column(name, :ltree, options) }
        end

        def macaddr(*args, **options)
          args.each { |name| column(name, :macaddr, options) }
        end

        def money(*args, **options)
          args.each { |name| column(name, :money, options) }
        end

        def numrange(*args, **options)
          args.each { |name| column(name, :numrange, options) }
        end

        def oid(*args, **options)
          args.each { |name| column(name, :oid, options) }
        end

        def point(*args, **options)
          args.each { |name| column(name, :point, options) }
        end

        def line(*args, **options)
          args.each { |name| column(name, :line, options) }
        end

        def lseg(*args, **options)
          args.each { |name| column(name, :lseg, options) }
        end

        def box(*args, **options)
          args.each { |name| column(name, :box, options) }
        end

        def path(*args, **options)
          args.each { |name| column(name, :path, options) }
        end

        def polygon(*args, **options)
          args.each { |name| column(name, :polygon, options) }
        end

        def circle(*args, **options)
          args.each { |name| column(name, :circle, options) }
        end

        def serial(*args, **options)
          args.each { |name| column(name, :serial, options) }
        end

        def tsrange(*args, **options)
          args.each { |name| column(name, :tsrange, options) }
        end

        def tstzrange(*args, **options)
          args.each { |name| column(name, :tstzrange, options) }
        end

        def tsvector(*args, **options)
          args.each { |name| column(name, :tsvector, options) }
        end

        def uuid(*args, **options)
          args.each { |name| column(name, :uuid, options) }
        end

        def xml(*args, **options)
          args.each { |name| column(name, :xml, options) }
        end
      end

      class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
        include ColumnMethods
      end

      class Table < ActiveRecord::ConnectionAdapters::Table
        include ColumnMethods
      end
    end
  end
end
