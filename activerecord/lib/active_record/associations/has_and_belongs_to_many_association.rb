require 'active_support/deprecation'

module ActiveRecord
  # = Active Record Has And Belongs To Many Association
  module Associations
    class HasAndBelongsToManyAssociation < AssociationCollection #:nodoc:
      def initialize(owner, reflection)
        super
        if columns.size > 2
          ActiveSupport::Deprecation.warn "Having additional attributes on the join table of a has_and_belongs_to_many association is deprecated and will be removed in Rails 3.1. Please use a has_many :through association instead."
        end
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
        @has_primary_key ||= @owner.connection.supports_primary_key? && @owner.connection.primary_key(@reflection.options[:join_table])
      end

      protected
        def construct_find_options!(options)
          options[:joins]      = Arel::SqlLiteral.new @join_sql
          options[:readonly]   = finding_with_ambiguous_select?(options[:select] || @reflection.options[:select])
          options[:select]   ||= (@reflection.options[:select] || Arel::SqlLiteral.new('*'))
        end

        def count_records
          load_target.size
        end

        def insert_record(record, force = true, validate = true)
          if record.new_record?
            if force
              record.save!
            else
              return false unless record.save(:validate => validate)
            end
          end

          if @reflection.options[:insert_sql]
            @owner.connection.insert(interpolate_sql(@reflection.options[:insert_sql], record))
          else
            relation   = Arel::Table.new(@reflection.options[:join_table])
            timestamps = record_timestamp_columns(record)
            timezone   = record.send(:current_time_from_proper_timezone) if timestamps.any?

            attributes = Hash[columns.map do |column|
              name = column.name
              value = case name.to_s
                when @reflection.primary_key_name.to_s
                  @owner.id
                when @reflection.association_foreign_key.to_s
                  record.id
                when *timestamps
                  timezone
                else
                  @owner.send(:quote_value, record[name], column) if record.has_attribute?(name)
              end
              [relation[name], value] unless value.nil?
            end]

            relation.insert(attributes)
          end

          return true
        end

        def delete_records(records)
          if sql = @reflection.options[:delete_sql]
            records.each { |record| @owner.connection.delete(interpolate_sql(sql, record)) }
          else
            relation = Arel::Table.new(@reflection.options[:join_table])
            relation.where(relation[@reflection.primary_key_name].eq(@owner.id).
              and(relation[@reflection.association_foreign_key].in(records.map { |x| x.id }.compact))
            ).delete
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

          construct_counter_sql
        end

        def construct_scope
          { :find => {  :conditions => @finder_sql,
                        :joins => @join_sql,
                        :readonly => false,
                        :order => @reflection.options[:order],
                        :include => @reflection.options[:include],
                        :limit => @reflection.options[:limit] } }
        end

        # Join tables with additional columns on top of the two foreign keys must be considered
        # ambiguous unless a select clause has been explicitly defined. Otherwise you can get
        # broken records back, if, for example, the join column also has an id column. This will
        # then overwrite the id column of the records coming back.
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

        def record_timestamp_columns(record)
          if record.record_timestamps
            record.send(:all_timestamp_attributes).map { |x| x.to_s }
          else
            []
          end
        end
    end
  end
end
