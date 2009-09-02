module ActiveRecord
  module Associations
    class HasAndBelongsToManyAssociation < AssociationCollection #:nodoc:
      def initialize(owner, reflection)
        super
        @primary_key_list = {}
      end

      def create(attributes = {})
        create_record(attributes) { |record| insert_record(record) }
      end

      def create!(attributes = {})
        create_record(attributes) { |record| insert_record(record, true) }
      end

      def columns
        @reflection.columns(@reflection.options[:join_table], "#{@reflection.options[:join_table]} Columns")
      end

      def reset_column_information
        @reflection.reset_column_information
      end

      def has_primary_key?
        return @has_primary_key unless @has_primary_key.nil?
        @has_primary_key = (ActiveRecord::Base.connection.supports_primary_key? &&
          ActiveRecord::Base.connection.primary_key(@reflection.options[:join_table]))
      end

      protected
        def construct_find_options!(options)
          options[:joins]      = @join_sql
          options[:readonly]   = finding_with_ambiguous_select?(options[:select] || @reflection.options[:select])
          options[:select]   ||= (@reflection.options[:select] || '*')
        end
        
        def count_records
          load_target.size
        end

        def insert_record(record, force = true, validate = true)
          if has_primary_key?
            raise ActiveRecord::ConfigurationError,
              "Primary key is not allowed in a has_and_belongs_to_many join table (#{@reflection.options[:join_table]})."
          end

          if record.new_record?
            if force
              record.save!
            else
              return false unless record.save(validate)
            end
          end

          if @reflection.options[:insert_sql]
            @owner.connection.insert(interpolate_sql(@reflection.options[:insert_sql], record))
          else
            attributes = columns.inject({}) do |attrs, column|
              case column.name.to_s
                when @reflection.primary_key_name.to_s
                  attrs[column.name] = owner_quoted_id
                when @reflection.association_foreign_key.to_s
                  attrs[column.name] = record.quoted_id
                else
                  if record.has_attribute?(column.name)
                    value = @owner.send(:quote_value, record[column.name], column)
                    attrs[column.name] = value unless value.nil?
                  end
              end
              attrs
            end

            sql =
              "INSERT INTO #{@owner.connection.quote_table_name @reflection.options[:join_table]} (#{@owner.send(:quoted_column_names, attributes).join(', ')}) " +
              "VALUES (#{attributes.values.join(', ')})"

            @owner.connection.insert(sql)
          end

          return true
        end

        def delete_records(records)
          if sql = @reflection.options[:delete_sql]
            records.each { |record| @owner.connection.delete(interpolate_sql(sql, record)) }
          else
            ids = quoted_record_ids(records)
            sql = "DELETE FROM #{@owner.connection.quote_table_name @reflection.options[:join_table]} WHERE #{@reflection.primary_key_name} = #{owner_quoted_id} AND #{@reflection.association_foreign_key} IN (#{ids})"
            @owner.connection.delete(sql)
          end
        end

        def construct_sql
          if @reflection.options[:finder_sql]
            @finder_sql = interpolate_sql(@reflection.options[:finder_sql])
          else
            @finder_sql = "#{@owner.connection.quote_table_name @reflection.options[:join_table]}.#{@reflection.primary_key_name} = #{owner_quoted_id} "
            @finder_sql << " AND (#{conditions})" if conditions
          end

          @join_sql = "INNER JOIN #{@owner.connection.quote_table_name @reflection.options[:join_table]} ON #{@reflection.quoted_table_name}.#{@reflection.klass.primary_key} = #{@owner.connection.quote_table_name @reflection.options[:join_table]}.#{@reflection.association_foreign_key}"

          if @reflection.options[:counter_sql]
            @counter_sql = interpolate_sql(@reflection.options[:counter_sql])
          elsif @reflection.options[:finder_sql]
            # replace the SELECT clause with COUNT(*), preserving any hints within /* ... */
            @reflection.options[:counter_sql] = @reflection.options[:finder_sql].sub(/SELECT (\/\*.*?\*\/ )?(.*)\bFROM\b/im) { "SELECT #{$1}COUNT(*) FROM" }
            @counter_sql = interpolate_sql(@reflection.options[:counter_sql])
          else
            @counter_sql = @finder_sql
          end
        end

        def construct_scope
          { :find => {  :conditions => @finder_sql,
                        :joins => @join_sql,
                        :readonly => false,
                        :order => @reflection.options[:order],
                        :include => @reflection.options[:include],
                        :limit => @reflection.options[:limit] } }
        end

        # Join tables with additional columns on top of the two foreign keys must be considered ambiguous unless a select
        # clause has been explicitly defined. Otherwise you can get broken records back, if, for example, the join column also has
        # an id column. This will then overwrite the id column of the records coming back.
        def finding_with_ambiguous_select?(select_clause)
          !select_clause && columns.size != 2
        end

      private
        def create_record(attributes, &block)
          # Can't use Base.create because the foreign key may be a protected attribute.
          ensure_owner_is_not_new
          if attributes.is_a?(Array)
            attributes.collect { |attr| create(attr) }
          else
            build_record(attributes, &block)
          end
        end
    end
  end
end
