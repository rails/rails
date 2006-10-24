module ActiveRecord
  module Associations # :nodoc:
    module ClassMethods
      def deprecated_collection_count_method(collection_name)# :nodoc:
        module_eval <<-"end_eval", __FILE__, __LINE__
          def #{collection_name}_count(force_reload = false)
            unless has_attribute?(:#{collection_name}_count)
              ActiveSupport::Deprecation.warn :#{collection_name}_count
            end
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
          deprecate :add_#{association_name} => "use #{association_name}.concat instead"
        end_eval
      end

      def deprecated_remove_association_relation(association_name)# :nodoc:
        module_eval <<-"end_eval", __FILE__, __LINE__
          def remove_#{association_name}(*items)
            #{association_name}.delete(items)
          end
          deprecate :remove_#{association_name} => "use #{association_name}.delete instead"
        end_eval
      end

      def deprecated_has_collection_method(collection_name)# :nodoc:
        module_eval <<-"end_eval", __FILE__, __LINE__
          def has_#{collection_name}?(force_reload = false)
            !#{collection_name}(force_reload).empty?
          end
          deprecate :has_#{collection_name}? => "use !#{collection_name}.empty? instead"
        end_eval
      end

      def deprecated_find_in_collection_method(collection_name)# :nodoc:
        module_eval <<-"end_eval", __FILE__, __LINE__
          def find_in_#{collection_name}(association_id)
            #{collection_name}.find(association_id)
          end
          deprecate :find_in_#{collection_name} => "use #{collection_name}.find instead"
        end_eval
      end

      def deprecated_find_all_in_collection_method(collection_name)# :nodoc:
        module_eval <<-"end_eval", __FILE__, __LINE__
          def find_all_in_#{collection_name}(runtime_conditions = nil, orderings = nil, limit = nil, joins = nil)
            ActiveSupport::Deprecation.silence do
              #{collection_name}.find_all(runtime_conditions, orderings, limit, joins)
            end
          end
          deprecate :find_all_in_#{collection_name} => "use #{collection_name}.find(:all, ...) instead"
        end_eval
      end

      def deprecated_collection_create_method(collection_name)# :nodoc:
        module_eval <<-"end_eval", __FILE__, __LINE__
          def create_in_#{collection_name}(attributes = {})
            #{collection_name}.create(attributes)
          end
          deprecate :create_in_#{collection_name} => "use #{collection_name}.create instead"
        end_eval
      end

      def deprecated_collection_build_method(collection_name)# :nodoc:
        module_eval <<-"end_eval", __FILE__, __LINE__
          def build_to_#{collection_name}(attributes = {})
            #{collection_name}.build(attributes)
          end
          deprecate :build_to_#{collection_name} => "use #{collection_name}.build instead"
        end_eval
      end

      def deprecated_association_comparison_method(association_name, association_class_name) # :nodoc:
        module_eval <<-"end_eval", __FILE__, __LINE__
          def #{association_name}?(comparison_object, force_reload = false)
            if comparison_object.kind_of?(#{association_class_name})
              #{association_name}(force_reload) == comparison_object
            else
              raise "Comparison object is a #{association_class_name}, should have been \#{comparison_object.class.name}"
            end
          end
          deprecate :#{association_name}? => :==
        end_eval
      end

      def deprecated_has_association_method(association_name) # :nodoc:
        module_eval <<-"end_eval", __FILE__, __LINE__
          def has_#{association_name}?(force_reload = false)
            !#{association_name}(force_reload).nil?
          end
          deprecate :has_#{association_name}? => "use !#{association_name} insead"
        end_eval
      end
    end
  end
end
