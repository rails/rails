# Allows attributes to be shared within an inheritance hierarchy, but where each descentent gets a copy of
# their parents' attributes, instead of just a pointer to the same. This means that the child can add elements
# to, for example, an array without those additions being shared with either their parent, siblings, or
# children, which is unlike the regular class-level attributes that are shared across the entire hierarchy.
module ClassInheritableAttributes # :nodoc:
  def self.append_features(base)
    super
    base.extend(ClassMethods)
  end
  
  module ClassMethods # :nodoc:
    @@classes ||= {}
    
    def inheritable_attributes
      @@classes[self] ||= {}
    end
    
    def write_inheritable_attribute(key, value)
      inheritable_attributes[key] = value
    end
    
    def write_inheritable_array(key, elements)
      write_inheritable_attribute(key, []) if read_inheritable_attribute(key).nil?
      write_inheritable_attribute(key, read_inheritable_attribute(key) + elements)
    end

    def read_inheritable_attribute(key)
      inheritable_attributes[key]
    end
    
    private 
      def inherited(child)
        @@classes[child] = inheritable_attributes.dup
      end
      
  end
end
