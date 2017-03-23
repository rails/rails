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
  # False for method objects;
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
    "symbol_from_string".to_sym.dup # Some symbols can't `dup` in Ruby 2.4.0.
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

require "bigdecimal"
class BigDecimal
  # BigDecimals are duplicable:
  #
  # BigDecimal.new("1.2").duplicable? # => true
  # BigDecimal.new("1.2").dup         # => #<BigDecimal:...,'0.12E1',18(18)>
  def duplicable?
    true
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

class Complex
  begin
    Complex(1).dup
  rescue TypeError

    # Complexes are not duplicable for RUBY_VERSION < 2.5.0:
    #
    # Complex(1).duplicable? # => false
    # Complex(1).dup         # => TypeError: can't copy Complex
    def duplicable?
      false
    end
  end
end

class Rational
  begin
    Rational(1).dup
  rescue TypeError

    # Rationals are not duplicable for RUBY_VERSION < 2.5.0:
    #
    # Rational(1).duplicable? # => false
    # Rational(1).dup         # => TypeError: can't copy Rational
    def duplicable?
      false
    end
  end
end
