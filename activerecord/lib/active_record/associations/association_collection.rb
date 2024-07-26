module ActiveRecord
  module Associations
    class AssociationCollection #:nodoc:
      alias_method :proxy_respond_to?, :respond_to?
      instance_methods.each { |m| undef_method m unless m =~ /(^__|^nil\?|^proxy_respond_to\?)/ }
      
      def initialize(owner, association_name, association_class_name, association_class_primary_key_name, options)
        @owner = owner
        @options = options
        @association_name = association_name
        @association_class = eval(association_class_name)
        @association_class_primary_key_name = association_class_primary_key_name
      end
      
      def method_missing(symbol, *args, &block)
        load_collection_to_array
        @collection_array.send(symbol, *args, &block)
      end
  
      def to_ary
        load_collection_to_array
        @collection_array.to_ary
      end
      
      def respond_to?(symbol)
        proxy_respond_to?(symbol) || [].respond_to?(symbol)
      end
      
      def reload
        @collection_array = nil
      end
      
      def concat(*records)
        records.flatten!
        records.each {|record| self << record; }
      end
      
      def destroy_all
        load_collection_to_array
        @collection_array.each { |object| object.destroy  }
        @collection_array = []
      end
      
      def size
        (@collection_array.nil?) ? count_records : @collection_array.size
      end
      
      def empty?
        size == 0
      end
      
      alias_method :length, :size
      
      private
        def load_collection_to_array
          return unless @collection_array.nil? 
          begin
            @collection_array = find_all_records
          rescue ActiveRecord::StatementInvalid, ActiveRecord::RecordNotFound
            @collection_array = []
          end       
        end
        
        def duplicated_records_array(records)
          records = [records] unless records.is_a?(Array) || records.is_a?(ActiveRecord::Associations::AssociationCollection)
          records.dup
        end
    end
  end
end