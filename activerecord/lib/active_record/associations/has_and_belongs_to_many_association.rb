module ActiveRecord
  # = Active Record Has And Belongs To Many Association
  module Associations
    class HasAndBelongsToManyAssociation < AssociationCollection #:nodoc:
      attr_reader :join_table

      def initialize(owner, reflection)
        @join_table_name = reflection.options[:join_table]
        @join_table      = Arel::Table.new(@join_table_name)
        super
      end

      protected

        def count_records
          load_target.size
        end

        def insert_record(record, force = true, validate = true)
          if record.new_record?
            return false unless save_record(record, force, validate)
          end

          if @reflection.options[:insert_sql]
            @owner.connection.insert(interpolate_sql(@reflection.options[:insert_sql], record))
          else
            stmt = join_table.compile_insert(
              join_table[@reflection.foreign_key]             => @owner.id,
              join_table[@reflection.association_foreign_key] => record.id
            )

            @owner.connection.insert stmt.to_sql
          end

          true
        end

        def delete_records(records)
          if sql = @reflection.options[:delete_sql]
            records.each { |record| @owner.connection.delete(interpolate_sql(sql, record)) }
          else
            relation = join_table
            stmt = relation.where(relation[@reflection.foreign_key].eq(@owner.id).
              and(relation[@reflection.association_foreign_key].in(records.map { |x| x.id }.compact))
            ).compile_delete
            @owner.connection.delete stmt.to_sql
          end
        end

        def construct_joins
          right = join_table
          left  = @reflection.klass.arel_table

          condition = left[@reflection.klass.primary_key].eq(
            right[@reflection.association_foreign_key])

          right.create_join(right, right.create_on(condition))
        end

        def construct_owner_conditions
          super(join_table)
        end

        def association_scope
          super.joins(construct_joins)
        end

        def select_value
          super || @reflection.klass.arel_table[Arel.star]
        end

      private
        def invertible_for?(record)
          false
        end
    end
  end
end
