#--
# Most objects are cloneable, but not all. For example you can't dup methods:
#
#   method(:puts).dup # => TypeError: allocator undefined for Method
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
  # False for +nil+, +false+, +true+, symbol, number and BigDecimal(in 1.9.x) objects;
  # true otherwise.
  def duplicable?
    true
  end
end

class NilClass
  begin
    nil.dup
  rescue TypeError

    # +nil+ is not duplicable:
    #
    #   nil.duplicable? # => false
    #   nil.dup         # => TypeError: can't dup NilClass
    def duplicable?
      false
    end
  end
end

class FalseClass
  begin
    false.dup
  rescue TypeError

    # +false+ is not duplicable:
    #
    #   false.duplicable? # => false
    #   false.dup         # => TypeError: can't dup FalseClass
    def duplicable?
      false
    end
  end
end

class TrueClass
  begin
    true.dup
  rescue TypeError

    # +true+ is not duplicable:
    #
    #   true.duplicable? # => false
    #   true.dup         # => TypeError: can't dup TrueClass
    def duplicable?
      false
    end
  end
end

class Symbol
  begin
    :symbol.dup # Ruby 2.4.x.
    'symbol_from_string'.to_sym.dup # Some symbols can't `dup` in Ruby 2.4.0.
  rescue TypeError

    # Symbols are not duplicable:
    #
    #   :my_symbol.duplicable? # => false
    #   :my_symbol.dup         # => TypeError: can't dup Symbol
    def duplicable?
      false
    end
  end
end

class Numeric
  begin
    1.dup
  rescue TypeError

    # Numbers are not duplicable:
    #
    #  3.duplicable? # => false
    #  3.dup         # => TypeError: can't dup Integer
    def duplicable?
      false
    end
  end
end

require 'bigdecimal'
class BigDecimal
  # Needed to support Ruby 1.9.x, as it doesn't allow dup on BigDecimal, instead
  # raises TypeError exception. Checking here on the runtime whether BigDecimal
  # will allow dup or not.
  begin
    BigDecimal.new('4.56').dup

    def duplicable?
      true
    end
  rescue TypeError
    # can't dup, so use superclass implementation
  end
end

class Method
  # Methods are not duplicable:
  #
  #  method(:puts).duplicable? # => false
  #  method(:puts).dup         # => TypeError: allocator undefined for Method
  def duplicable?
    false
  end
end
