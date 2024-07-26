module ActiveRecord
  module Associations # :nodoc:
    module ClassMethods
      def deprecated_collection_count_method(collection_name)# :nodoc:
        module_eval <<-"end_eval", __FILE__, __LINE__
          def #{collection_name}_count(force_reload = false)
            #{collection_name}.reload if force_reload
            #{collection_name}.size
          end
        end_eval
      end
      
      def deprecated_add_association_relation(association_name)# :nodoc:
        module_eval <<-"end_eval", __FILE__, __LINE__
          def add_#{association_name}(*items)
            #{association_name}.concat(items)
          end
        end_eval
      end
    
       def deprecated_remove_association_relation(association_name)# :nodoc:
        module_eval <<-"end_eval", __FILE__, __LINE__
          def remove_#{association_name}(*items)
            #{association_name}.delete(items)
          end
        end_eval
      end
    
      def deprecated_has_collection_method(collection_name)# :nodoc:
        module_eval <<-"end_eval", __FILE__, __LINE__
          def has_#{collection_name}?(force_reload = false)
            !#{collection_name}(force_reload).empty?
          end
        end_eval
      end
      
      def deprecated_find_in_collection_method(collection_name)# :nodoc:
        module_eval <<-"end_eval", __FILE__, __LINE__
          def find_in_#{collection_name}(association_id)
            #{collection_name}.find(association_id)
          end
        end_eval
      end
      
      def deprecated_find_all_in_collection_method(collection_name)# :nodoc:
        module_eval <<-"end_eval", __FILE__, __LINE__
          def find_all_in_#{collection_name}(runtime_conditions = nil, orderings = nil, limit = nil, joins = nil)
            #{collection_name}.find_all(runtime_conditions, orderings, limit, joins)
          end
        end_eval
      end
    
      def deprecated_create_method(collection_name)# :nodoc:
        module_eval <<-"end_eval", __FILE__, __LINE__
          def create_in_#{collection_name}(attributes = {})
            #{collection_name}.create(attributes)
          end
        end_eval
      end
    
      def deprecated_build_method(collection_name)# :nodoc:
          module_eval <<-"end_eval", __FILE__, __LINE__
            def build_to_#{collection_name}(attributes = {})
              #{collection_name}.build(attributes)
            end
          end_eval
        end
    end
  end
end
