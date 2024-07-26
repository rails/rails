module ActiveRecord
  module Associations
    class HasAndBelongsToManyCollection < AssociationCollection #:nodoc:
      def initialize(owner, association_name, association_class_name, association_class_primary_key_name, join_table, options)
        super(owner, association_name, association_class_name, association_class_primary_key_name, options)
        
        @association_foreign_key = options[:association_foreign_key] || association_class_name.downcase + "_id"
        association_table_name = options[:table_name] || @association_class.table_name(association_class_name)
        @join_table = join_table
        @order = options[:order] || "t.#{@owner.class.primary_key}"

        @finder_sql = options[:finder_sql] ||
              "SELECT t.* FROM #{association_table_name} t, #{@join_table} j " +
              "WHERE t.#{@owner.class.primary_key} = j.#{@association_foreign_key} AND " +
              "j.#{association_class_primary_key_name} = '#{@owner.id}' ORDER BY #{@order}"
      end
        
      def <<(record)
        raise ActiveRecord::AssociationTypeMismatch unless @association_class === record
        sql = @options[:insert_sql] || 
            "INSERT INTO #{@join_table} (#{@association_class_primary_key_name}, #{@association_foreign_key}) " +
            "VALUES ('#{@owner.id}', '#{record.id}')"
        @owner.connection.execute(sql)
        @collection_array << record unless @collection_array.nil?
      end
        
      def delete(records)
        records = duplicated_records_array(records)
        sql = @options[:delete_sql] || "DELETE FROM #{@join_table} WHERE #{@association_class_primary_key_name} = '#{@owner.id}'"
        ids = records.map { |record| "'" + record.id.to_s + "'" }.join(',')
        @owner.connection.delete "#{sql} AND #{@association_foreign_key} in (#{ids})"
        records.each {|record| @collection_array.delete(record) } unless @collection_array.nil?
      end
        
      protected
        def find_all_records
          @association_class.find_by_sql(@finder_sql)
        end
            
        def count_records
          load_collection_to_array
          @collection_array.size
        end
      end
  end
end