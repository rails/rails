module ActiveRecord
  module Associations
    class HasAndBelongsToManyAssociation < AssociationCollection #:nodoc:
      def initialize(owner, reflection)
        super
        construct_sql
      end

      def build(attributes = {})
        load_target
        build_record(attributes)
      end

      def create(attributes = {})
        create_record(attributes) { |record| insert_record(record) }
      end

      def create!(attributes = {})
        create_record(attributes) { |record| insert_record(record, true) }
      end

      def find_first
        load_target.first
      end

      def find(*args)
        options = args.extract_options!

        # If using a custom finder_sql, scan the entire collection.
        if @reflection.options[:finder_sql]
          expects_array = args.first.kind_of?(Array)
          ids = args.flatten.compact.uniq

          if ids.size == 1
            id = ids.first.to_i
            record = load_target.detect { |r| id == r.id }
            expects_array ? [record] : record
          else
            load_target.select { |r| ids.include?(r.id) }
          end
        else
          conditions = "#{@finder_sql}"

          if sanitized_conditions = sanitize_sql(options[:conditions])
            conditions << " AND (#{sanitized_conditions})"
          end

          options[:conditions] = conditions
          options[:joins]      = @join_sql
          options[:readonly]   = finding_with_ambiguous_select?(options[:select] || @reflection.options[:select])

          if options[:order] && @reflection.options[:order]
            options[:order] = "#{options[:order]}, #{@reflection.options[:order]}"
          elsif @reflection.options[:order]
            options[:order] = @reflection.options[:order]
          end

          merge_options_from_reflection!(options)

          options[:select] ||= (@reflection.options[:select] || '*')

          # Pass through args exactly as we received them.
          args << options
          @reflection.klass.find(*args)
        end
      end

      protected
        def count_records
          load_target.size
        end

        def insert_record(record, force=true)
          if record.new_record?
            if force
              record.save!
            else
              return false unless record.save
            end
          end

          if @reflection.options[:insert_sql]
            @owner.connection.insert(interpolate_sql(@reflection.options[:insert_sql], record))
          else
            columns = @owner.connection.columns(@reflection.options[:join_table], "#{@reflection.options[:join_table]} Columns")

            attributes = columns.inject({}) do |attrs, column|
              case column.name
                when @reflection.primary_key_name
                  attrs[column.name] = @owner.quoted_id
                when @reflection.association_foreign_key
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
              "INSERT INTO #{@reflection.options[:join_table]} (#{@owner.send(:quoted_column_names, attributes).join(', ')}) " +
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
            sql = "DELETE FROM #{@owner.connection.quote_table_name @reflection.options[:join_table]} WHERE #{@reflection.primary_key_name} = #{@owner.quoted_id} AND #{@reflection.association_foreign_key} IN (#{ids})"
            @owner.connection.delete(sql)
          end
        end

        def construct_sql
          interpolate_sql_options!(@reflection.options, :finder_sql)

          if @reflection.options[:finder_sql]
            @finder_sql = @reflection.options[:finder_sql]
          else
            @finder_sql = "#{@reflection.options[:join_table]}.#{@reflection.primary_key_name} = #{@owner.quoted_id} "
            @finder_sql << " AND (#{conditions})" if conditions
          end

          @join_sql = "INNER JOIN #{@reflection.options[:join_table]} ON #{@reflection.klass.table_name}.#{@reflection.klass.primary_key} = #{@reflection.options[:join_table]}.#{@reflection.association_foreign_key}"
        end

        def construct_scope
          { :find => {  :conditions => @finder_sql,
                        :joins => @join_sql,
                        :readonly => false,
                        :order => @reflection.options[:order],
                        :limit => @reflection.options[:limit] } }
        end

        # Join tables with additional columns on top of the two foreign keys must be considered ambiguous unless a select
        # clause has been explicitly defined. Otherwise you can get broken records back, if, for example, the join column also has
        # an id column. This will then overwrite the id column of the records coming back.
        def finding_with_ambiguous_select?(select_clause)
          !select_clause && @owner.connection.columns(@reflection.options[:join_table], "Join Table Columns").size != 2
        end

      private
        def create_record(attributes)
          # Can't use Base.create because the foreign key may be a protected attribute.
          ensure_owner_is_not_new
          if attributes.is_a?(Array)
            attributes.collect { |attr| create(attr) }
          else
            record = build(attributes)
            yield(record)
            record
          end
        end
    end
  end
end
