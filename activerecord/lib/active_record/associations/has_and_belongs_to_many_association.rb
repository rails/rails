module ActiveRecord
  # = Active Record Has And Belongs To Many Association
  module Associations
    class HasAndBelongsToManyAssociation < AssociationCollection #:nodoc:
      def columns
        @reflection.columns(@reflection.options[:join_table], "#{@reflection.options[:join_table]} Columns")
      end

      def reset_column_information
        @reflection.reset_column_information
      end

      def has_primary_key?
        @has_primary_key ||= @owner.connection.supports_primary_key? && @owner.connection.primary_key(@reflection.options[:join_table])
      end

      protected
        def construct_find_options!(options)
          options[:joins]      = Arel::SqlLiteral.new(@scope[:find][:joins])
          options[:readonly]   = finding_with_ambiguous_select?(options[:select] || @reflection.options[:select])
          options[:select]   ||= (@reflection.options[:select] || Arel::SqlLiteral.new('*'))
        end

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
            relation   = Arel::Table.new(@reflection.options[:join_table])
            timestamps = record_timestamp_columns(record)
            timezone   = record.send(:current_time_from_proper_timezone) if timestamps.any?

            attributes = columns.map do |column|
              name = column.name
              value = case name.to_s
                when @reflection.foreign_key.to_s
                  @owner.id
                when @reflection.association_foreign_key.to_s
                  record.id
                when *timestamps
                  timezone
                else
                  @owner.send(:quote_value, record[name], column) if record.has_attribute?(name)
              end
              [relation[name], value] unless value.nil?
            end

            stmt = relation.compile_insert Hash[attributes]
            @owner.connection.insert stmt.to_sql
          end

          true
        end

        def delete_records(records)
          if sql = @reflection.options[:delete_sql]
            records.each { |record| @owner.connection.delete(interpolate_sql(sql, record)) }
          else
            relation = Arel::Table.new(@reflection.options[:join_table])
            stmt = relation.where(relation[@reflection.foreign_key].eq(@owner.id).
              and(relation[@reflection.association_foreign_key].in(records.map { |x| x.id }.compact))
            ).compile_delete
            @owner.connection.delete stmt.to_sql
          end
        end

        def construct_joins
          "INNER JOIN #{@owner.connection.quote_table_name @reflection.options[:join_table]} ON #{@reflection.quoted_table_name}.#{@reflection.klass.primary_key} = #{@owner.connection.quote_table_name @reflection.options[:join_table]}.#{@reflection.association_foreign_key}"
        end

        def join_table
          Arel::Table.new(@reflection.options[:join_table])
        end

        def construct_owner_conditions
          super(join_table)
        end

        def construct_find_scope
          {
            :conditions => construct_conditions,
            :joins      => construct_joins,
            :readonly   => false,
            :order      => @reflection.options[:order],
            :include    => @reflection.options[:include],
            :limit      => @reflection.options[:limit]
          }
        end

        # Join tables with additional columns on top of the two foreign keys must be considered
        # ambiguous unless a select clause has been explicitly defined. Otherwise you can get
        # broken records back, if, for example, the join column also has an id column. This will
        # then overwrite the id column of the records coming back.
        def finding_with_ambiguous_select?(select_clause)
          !select_clause && columns.size != 2
        end

      private
        def record_timestamp_columns(record)
          if record.record_timestamps
            record.send(:all_timestamp_attributes).map { |x| x.to_s }
          else
            []
          end
        end

        def invertible_for?(record)
          false
        end
    end
  end
end
