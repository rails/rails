#--
# Most objects are cloneable, but not all. For example you can't dup +nil+:
#
#   nil.dup # => TypeError: can't dup NilClass
#
# Classes may signal their instances are not duplicable removing +dup+/+clone+
# or raising exceptions from them. So, to dup an arbitrary object you normally
# use an optimistic approach and are ready to catch an exception, say:
#
#   arbitrary_object.dup rescue object
#
# Rails dups objects in a few critical spots where they are not that arbitrary.
# That rescue is very expensive (like 40 times slower than a predicate), and it
# is often triggered.
#
# That's why we hardcode the following cases and check duplicable? instead of
# using that rescue idiom.
#++
class Object
  # Can you safely dup this object?
  #
  # False for +nil+, +false+, +true+, symbols, numbers, class and module objects;
  # true otherwise.
  def duplicable?
    true
  end
end

class NilClass
  # +nil+ is not duplicable:
  #
  #   nil.duplicable? # => false
  #   nil.dup         # => TypeError: can't dup NilClass
  #
  def duplicable?
    false
  end
end

class FalseClass
  # +false+ is not duplicable:
  #
  #   false.duplicable? # => false
  #   false.dup         # => TypeError: can't dup FalseClass
  #
  def duplicable?
    false
  end
end

class TrueClass
  # +true+ is not duplicable:
  #
  #   true.duplicable? # => false
  #   true.dup         # => TypeError: can't dup TrueClass
  #
  def duplicable?
    false
  end
end

class Symbol
  # Symbols are not duplicable:
  #
  #   :my_symbol.duplicable? # => false
  #   :my_symbol.dup         # => TypeError: can't dup Symbol
  #
  def duplicable?
    false
  end
end

class Numeric
  # Numbers are not duplicable:
  #
  #  3.duplicable? # => false
  #  3.dup         # => TypeError: can't dup Fixnum
  #
  def duplicable?
    false
  end
end

class Class
  # Classes are not duplicable:
  #
  #  c = Class.new # => #<Class:0x10328fd80>
  #  c.dup         # => #<Class:0x10328fd80>
  #
  # Note +dup+ returned the same class object.
  def duplicable?
    false
  end
end

class Module
  # Modules are not duplicable:
  #
  #  m = Module.new # => #<Module:0x10328b6e0>
  #  m.dup          # => #<Module:0x10328b6e0>
  #
  # Note +dup+ returned the same module object.
  def duplicable?
    false
  end
end

require 'bigdecimal'
class BigDecimal
  begin
    BigDecimal.new('4.56').dup

    def duplicable?
      true
    end
  rescue TypeError
    # can't dup, so use superclass implementation
  end
end
