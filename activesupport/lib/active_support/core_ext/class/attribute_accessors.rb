require 'active_support/core_ext/array/extract_options'

# Extends the class object with class and instance accessors for class attributes,
# just like the native attr* accessors for instance attributes.
#
# Note that unlike +class_attribute+, if a subclass changes the value then that would
# also change the value for parent class. Similarly if parent class changes the value
# then that would change the value of subclasses too.
#
#  class Person
#    cattr_accessor :hair_colors
#  end
#
#  Person.hair_colors = [:brown, :black, :blonde, :red]
#  Person.hair_colors     # => [:brown, :black, :blonde, :red]
#  Person.new.hair_colors # => [:brown, :black, :blonde, :red]
#
# To opt out of the instance writer method, pass :instance_writer => false.
# To opt out of the instance reader method, pass :instance_reader => false.
# To opt out of both instance methods, pass :instance_accessor => false.
#
#   class Person
#     cattr_accessor :hair_colors, :instance_writer => false, :instance_reader => false
#   end
#
#   Person.new.hair_colors = [:brown]  # => NoMethodError
#   Person.new.hair_colors             # => NoMethodError
class Class
  def cattr_reader(*syms)
    options = syms.extract_options!
    syms.each do |sym|
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
        unless defined? @@#{sym}
          @@#{sym} = nil
        end

        def self.#{sym}
          @@#{sym}
        end
      EOS

      unless options[:instance_reader] == false || options[:instance_accessor] == false
        class_eval(<<-EOS, __FILE__, __LINE__ + 1)
          def #{sym}
            @@#{sym}
          end
        EOS
      end
    end
  end

  def cattr_writer(*syms)
    options = syms.extract_options!
    syms.each do |sym|
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
        unless defined? @@#{sym}
          @@#{sym} = nil
        end

        def self.#{sym}=(obj)
          @@#{sym} = obj
        end
      EOS

      unless options[:instance_writer] == false || options[:instance_accessor] == false
        class_eval(<<-EOS, __FILE__, __LINE__ + 1)
          def #{sym}=(obj)
            @@#{sym} = obj
          end
        EOS
      end
      self.send("#{sym}=", yield) if block_given?
    end
  end

  def cattr_accessor(*syms, &blk)
    cattr_reader(*syms)
    cattr_writer(*syms, &blk)
  end
end
