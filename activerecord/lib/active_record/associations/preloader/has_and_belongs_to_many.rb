module ActiveRecord
  module Associations
    class Preloader
      class HasAndBelongsToMany < CollectionAssociation #:nodoc:
        attr_reader :join_table

        def initialize(klass, records, reflection, preload_options)
          super
          @join_table = Arel::Table.new(options[:join_table]).alias('t0')
        end

        # Unlike the other associations, we want to get a raw array of rows so that we can
        # access the aliased column on the join table
        def records_for(ids)
          scope = super
          klass.connection.select_all(scope.arel, 'SQL', scope.bind_values)
        end

        def owner_key_name
          reflection.active_record_primary_key
        end

        def association_key_name
          'ar_association_key_name'
        end

        def association_key
          join_table[reflection.foreign_key]
        end

        private

        # Once we have used the join table column (in super), we manually instantiate the
        # actual records, ensuring that we don't create more than one instances of the same
        # record
        def associated_records_by_owner
          records = {}
          super.each do |owner_key, rows|
            rows.map! { |row| records[row[klass.primary_key]] ||= klass.instantiate(row) }
          end
        end

        def build_scope
          super.joins(join).select(join_select)
        end

        def join_select
          association_key.as(Arel.sql(association_key_name))
        end

        def join
          condition = table[reflection.association_primary_key].eq(
            join_table[reflection.association_foreign_key])

          table.create_join(join_table, table.create_on(condition))
        end
      end
    end
  end
end
