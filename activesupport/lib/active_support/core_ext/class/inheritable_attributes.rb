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
      next if sym.is_a?(Hash)
      class_eval <<-EOS
        def self.#{sym}                        # def self.before_add_for_comments
          read_inheritable_attribute(:#{sym})  #   read_inheritable_attribute(:before_add_for_comments)
        end                                    # end
                                               #
        def #{sym}                             # def before_add_for_comments
          self.class.#{sym}                    #   self.class.before_add_for_comments
        end                                    # end
      EOS
    end
  end

  def class_inheritable_writer(*syms)
    options = syms.extract_options!
    syms.each do |sym|
      class_eval <<-EOS
        def self.#{sym}=(obj)                          # def self.color=(obj)
          write_inheritable_attribute(:#{sym}, obj)    #   write_inheritable_attribute(:color, obj)
        end                                            # end
                                                       #
        #{"                                            #
        def #{sym}=(obj)                               # def color=(obj)
          self.class.#{sym} = obj                      #   self.class.color = obj
        end                                            # end
        " unless options[:instance_writer] == false }  # # the writer above is generated unless options[:instance_writer] == false
      EOS
    end
  end

  def class_inheritable_array_writer(*syms)
    options = syms.extract_options!
    syms.each do |sym|
      class_eval <<-EOS
        def self.#{sym}=(obj)                          # def self.levels=(obj)
          write_inheritable_array(:#{sym}, obj)        #   write_inheritable_array(:levels, obj)
        end                                            # end
                                                       #
        #{"                                            #
        def #{sym}=(obj)                               # def levels=(obj)
          self.class.#{sym} = obj                      #   self.class.levels = obj
        end                                            # end
        " unless options[:instance_writer] == false }  # # the writer above is generated unless options[:instance_writer] == false
      EOS
    end
  end

  def class_inheritable_hash_writer(*syms)
    options = syms.extract_options!
    syms.each do |sym|
      class_eval <<-EOS
        def self.#{sym}=(obj)                          # def self.nicknames=(obj)
          write_inheritable_hash(:#{sym}, obj)         #   write_inheritable_hash(:nicknames, obj)
        end                                            # end
                                                       #
        #{"                                            #
        def #{sym}=(obj)                               # def nicknames=(obj)
          self.class.#{sym} = obj                      #   self.class.nicknames = obj
        end                                            # end
        " unless options[:instance_writer] == false }  # # the writer above is generated unless options[:instance_writer] == false
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
    @inheritable_attributes ||= EMPTY_INHERITABLE_ATTRIBUTES
  end

  def write_inheritable_attribute(key, value)
    if inheritable_attributes.equal?(EMPTY_INHERITABLE_ATTRIBUTES)
      @inheritable_attributes = {}
    end
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
    @inheritable_attributes = EMPTY_INHERITABLE_ATTRIBUTES
  end

  private
    # Prevent this constant from being created multiple times
    EMPTY_INHERITABLE_ATTRIBUTES = {}.freeze unless const_defined?(:EMPTY_INHERITABLE_ATTRIBUTES)

    def inherited_with_inheritable_attributes(child)
      inherited_without_inheritable_attributes(child) if respond_to?(:inherited_without_inheritable_attributes)

      if inheritable_attributes.equal?(EMPTY_INHERITABLE_ATTRIBUTES)
        new_inheritable_attributes = EMPTY_INHERITABLE_ATTRIBUTES
      else
        new_inheritable_attributes = inheritable_attributes.inject({}) do |memo, (key, value)|
          memo.update(key => value.duplicable? ? value.dup : value)
        end
      end

      child.instance_variable_set('@inheritable_attributes', new_inheritable_attributes)
    end

    alias inherited_without_inheritable_attributes inherited
    alias inherited inherited_with_inheritable_attributes
end
