# Allows attributes to be shared within an inheritance hierarchy, but where each descentent get a copy of
# their parents attributes, instead of just a pointer to the same. This means that the child can add elements
# to for example an array without those additions are shared with either their parent, their brother, or their
# child. Which is unlike the regular class-level attributes that are shared across the entire hierarchy.
module ClassInheritableAttributes # :nodoc:
  def self.append_features(base)
    super
    base.class_eval "@@inheritable_attributes_for_#{base.name.split("::").last.downcase} = {}"
    base.extend(ClassMethods)
  end

  module ClassMethods # :nodoc:
    def write_inheritable_attribute(key, value)
      class_eval "#{class_inheritable_hash_name}[key] = value"
    end
    
    def write_inheritable_array(key, elements)
      write_inheritable_attribute(key, []) if read_inheritable_attribute(key).nil?
      write_inheritable_attribute(key, read_inheritable_attribute(key) + elements)
    end

    def read_inheritable_attribute(key)
      class_eval(class_inheritable_hash_name)[key]
    end
    
    private 
      def inherited(child)
        child.class_eval "#{class_inheritable_hash_name(child)} = #{class_inheritable_hash_name}.dup"
      end
      
      def class_inheritable_hash_name(for_class = self)
        "@@inheritable_attributes_for_#{for_class.name.split("::").last.downcase}"
      end
  end
end