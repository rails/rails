# Retain for backward compatibility.  Methods are now included in Class.
module ClassInheritableAttributes # :nodoc:
end

# Allows attributes to be shared within an inheritance hierarchy, but where each descendant gets a copy of
# their parents' attributes, instead of just a pointer to the same. This means that the child can add elements
# to, for example, an array without those additions being shared with either their parent, siblings, or
# children, which is unlike the regular class-level attributes that are shared across the entire hierarchy.
class Class # :nodoc:
  def class_inheritable_reader(*syms)
    syms.each do |sym|
      class_eval <<-EOS
        def self.#{sym}
          read_inheritable_attribute(:#{sym})
        end

        def #{sym}
          self.class.#{sym}
        end
      EOS
    end
  end

  def class_inheritable_writer(*syms)
    syms.each do |sym|
      class_eval <<-EOS
        def self.#{sym}=(obj)
          write_inheritable_attribute(:#{sym}, obj)
        end

        def #{sym}=(obj)
          self.class.#{sym} = obj
        end
      EOS
    end
  end

  def class_inheritable_array_writer(*syms)
    syms.each do |sym|
      class_eval <<-EOS
        def self.#{sym}=(obj)
          write_inheritable_array(:#{sym}, obj)
        end

        def #{sym}=(obj)
          self.class.#{sym} = obj
        end
      EOS
    end
  end

  def class_inheritable_hash_writer(*syms)
    syms.each do |sym|
      class_eval <<-EOS
        def self.#{sym}=(obj)
          write_inheritable_hash(:#{sym}, obj)
        end

        def #{sym}=(obj)
          self.class.#{sym} = obj
        end
      EOS
    end
  end

  def class_inheritable_accessor(*syms)
    class_inheritable_reader(*syms)
    class_inheritable_writer(*syms)
  end

  def class_inheritable_array(*syms)
    class_inheritable_reader(*syms)
    class_inheritable_array_writer(*syms)
  end

  def class_inheritable_hash(*syms)
    class_inheritable_reader(*syms)
    class_inheritable_hash_writer(*syms)
  end

  def inheritable_attributes
    @inheritable_attributes ||= {}
  end
  
  def write_inheritable_attribute(key, value)
    inheritable_attributes[key] = value
  end
  
  def write_inheritable_array(key, elements)
    write_inheritable_attribute(key, []) if read_inheritable_attribute(key).nil?
    write_inheritable_attribute(key, read_inheritable_attribute(key) + elements)
  end

  def write_inheritable_hash(key, hash)
    write_inheritable_attribute(key, {}) if read_inheritable_attribute(key).nil?
    write_inheritable_attribute(key, read_inheritable_attribute(key).merge(hash))
  end

  def read_inheritable_attribute(key)
    inheritable_attributes[key]
  end
  
  def reset_inheritable_attributes
    inheritable_attributes.clear
  end

  private 
    def inherited_with_inheritable_attributes(child)
      inherited_without_inheritable_attributes(child) if respond_to?(:inherited_without_inheritable_attributes)
      
      new_inheritable_attributes = inheritable_attributes.inject({}) do |memo, (key, value)|
        memo.update(key => (value.dup rescue value))
      end
      
      child.instance_variable_set('@inheritable_attributes', new_inheritable_attributes)
    end

    alias inherited_without_inheritable_attributes inherited
    alias inherited inherited_with_inheritable_attributes
end
