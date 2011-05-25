require 'active_support/core_ext/object/duplicable'
require 'active_support/core_ext/array/extract_options'
require 'active_support/deprecation'

# Retained for backward compatibility.  Methods are now included in Class.
module ClassInheritableAttributes # :nodoc:
  DEPRECATION_WARNING_MESSAGE = "class_inheritable_attribute is deprecated, please use class_attribute method instead. Notice their behavior are slightly different, so refer to class_attribute documentation first"
end

# It is recommended to use <tt>class_attribute</tt> over methods defined in this file. Please
# refer to documentation for <tt>class_attribute</tt> for more information. Officially it is not
# deprecated but <tt>class_attribute</tt> is faster.
#
# Allows attributes to be shared within an inheritance hierarchy. Each descendant gets a copy of
# their parents' attributes, instead of just a pointer to the same. This means that the child can add elements
# to, for example, an array without those additions being shared with either their parent, siblings, or
# children. This is unlike the regular class-level attributes that are shared across the entire hierarchy.
#
# The copies of inheritable parent attributes are added to subclasses when they are created, via the
# +inherited+ hook.
#
#  class Person
#    class_inheritable_accessor :hair_colors
#  end
#
#  Person.hair_colors = [:brown, :black, :blonde, :red]
#  Person.hair_colors     # => [:brown, :black, :blonde, :red]
#  Person.new.hair_colors # => [:brown, :black, :blonde, :red]
#
# To opt out of the instance writer method, pass :instance_writer => false.
# To opt out of the instance reader method, pass :instance_reader => false.
#
#   class Person
#     class_inheritable_accessor :hair_colors :instance_writer => false, :instance_reader => false
#   end
#
#   Person.new.hair_colors = [:brown]  # => NoMethodError
#   Person.new.hair_colors             # => NoMethodError
class Class # :nodoc:
  def class_inheritable_reader(*syms)
    ActiveSupport::Deprecation.warn ClassInheritableAttributes::DEPRECATION_WARNING_MESSAGE
    options = syms.extract_options!
    syms.each do |sym|
      next if sym.is_a?(Hash)
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
        def self.#{sym}                                # def self.after_add
          read_inheritable_attribute(:#{sym})          #   read_inheritable_attribute(:after_add)
        end                                            # end
                                                       #
        #{"                                            #
        def #{sym}                                     # def after_add
          self.class.#{sym}                            #   self.class.after_add
        end                                            # end
        " unless options[:instance_reader] == false }  # # the reader above is generated unless options[:instance_reader] == false
      EOS
    end
  end

  def class_inheritable_writer(*syms)
    ActiveSupport::Deprecation.warn ClassInheritableAttributes::DEPRECATION_WARNING_MESSAGE
    options = syms.extract_options!
    syms.each do |sym|
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
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
    ActiveSupport::Deprecation.warn ClassInheritableAttributes::DEPRECATION_WARNING_MESSAGE
    options = syms.extract_options!
    syms.each do |sym|
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
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
    ActiveSupport::Deprecation.warn ClassInheritableAttributes::DEPRECATION_WARNING_MESSAGE
    options = syms.extract_options!
    syms.each do |sym|
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
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
    ActiveSupport::Deprecation.warn ClassInheritableAttributes::DEPRECATION_WARNING_MESSAGE
    @inheritable_attributes = EMPTY_INHERITABLE_ATTRIBUTES
  end

  private
    # Prevent this constant from being created multiple times
    EMPTY_INHERITABLE_ATTRIBUTES = {}.freeze

    def inherited_with_inheritable_attributes(child)
      inherited_without_inheritable_attributes(child) if respond_to?(:inherited_without_inheritable_attributes)

      if inheritable_attributes.equal?(EMPTY_INHERITABLE_ATTRIBUTES)
        new_inheritable_attributes = EMPTY_INHERITABLE_ATTRIBUTES
      else
        new_inheritable_attributes = Hash[inheritable_attributes.map do |(key, value)|
          [key, value.duplicable? ? value.dup : value]
        end]
      end

      child.instance_variable_set('@inheritable_attributes', new_inheritable_attributes)
    end

    alias inherited_without_inheritable_attributes inherited
    alias inherited inherited_with_inheritable_attributes
end
