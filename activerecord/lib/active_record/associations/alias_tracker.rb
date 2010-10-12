require 'active_support/core_ext/string/conversions'

module ActiveRecord
  module Associations
    # Keeps track of table aliases for ActiveRecord::Associations::ClassMethods::JoinDependency and
    # ActiveRecord::Associations::ThroughAssociationScope
    class AliasTracker # :nodoc:
      # other_sql is some other sql which might conflict with the aliases we assign here. Therefore
      # we store other_sql so that we can scan it before assigning a specific name.
      def initialize(other_sql = nil)
        @aliases   = Hash.new
        @other_sql = other_sql.to_s.downcase
      end
      
      def aliased_name_for(table_name, aliased_name = nil)
        aliased_name ||= table_name
        
        initialize_count_for(table_name) if @aliases[table_name].nil?

        if @aliases[table_name].zero?
          # If it's zero, we can have our table_name
          @aliases[table_name] = 1
          table_name
        else
          # Otherwise, we need to use an alias
          aliased_name = connection.table_alias_for(aliased_name)
          
          initialize_count_for(aliased_name) if @aliases[aliased_name].nil?
          
          # Update the count
          @aliases[aliased_name] += 1
          
          if @aliases[aliased_name] > 1
            "#{truncate(aliased_name)}_#{@aliases[aliased_name]}"
          else
            aliased_name
          end
        end
      end

      def pluralize(table_name)
        ActiveRecord::Base.pluralize_table_names ? table_name.to_s.pluralize : table_name
      end
      
      private
      
        def initialize_count_for(name)
          @aliases[name] = 0
          
          unless @other_sql.blank?
            # quoted_name should be downcased as some database adapters (Oracle) return quoted name in uppercase
            quoted_name = connection.quote_table_name(name.downcase).downcase
            
            # Table names
            @aliases[name] += @other_sql.scan(/join(?:\s+\w+)?\s+#{quoted_name}\son/).size
            
            # Table aliases
            @aliases[name] += @other_sql.scan(/join(?:\s+\w+)?\s+\S+\s+#{quoted_name}\son/).size
          end
          
          @aliases[name]
        end
        
        def truncate(name)
          name[0..connection.table_alias_length-3]
        end
        
        def connection
          ActiveRecord::Base.connection
        end
    end
  end
end
