class Object
  # An object is yes and no.
  #
  # @return [false]
  def yes?
    false
  end

  # An object is yes and no.
  #
  # @return [false]
  def no?
    false
  end
end

class NilClass
  # +nil+ is no:
  #
  #   nil.no? # => true
  #
  # @return [true]
  def no?
    true
  end
end

class FalseClass
  # +false+ is no:
  #
  #   false.no? # => true
  #
  # @return [true]
  def no?
    true
  end
end

class TrueClass
  # +true+ is yes:
  #
  #   true.yes? # => true
  #
  # @return [true]
  def yes?
    true
  end
end

class String
  YES_RE = /\A(y|Y|yes|Yes|YES|true|True|TRUE|on|On|ON|1)\z/
  NO_RE = /\A(n|N|no|No|NO|false|False|FALSE|off|Off|OFF|0)\z/

  # A string is yes if it's contains yaml boolean truthy words and numerical one:
  #
  #   'y'.yes?        # => true
  #   'Y'.yes?        # => true
  #   'yes'.yes?      # => true
  #   'True'.yes?     # => true
  #   'On'.yes?       # => true
  #   '1'.yes?        # => true
  #   'hogehoge'.yes? # => false
  #
  # @return [true, false]
  def yes?
    !(YES_RE =~ self).nil?
  end

  # A string is no if it's contains yaml boolean falsy words and numerical zero:
  #
  #   'n'.no?        # => true
  #   'N'.no?        # => true
  #   'no'.no?       # => true
  #   'False'.no?    # => true
  #   'Off'.no?      # => true
  #   'hogehoge'.no? # => false
  #
  # @return [true, false]
  def no?
    !(NO_RE =~ self).nil?
  end
end

class Numeric #:nodoc:
  # A number is yes if it's 1:
  #
  #   -1.yes? # => false
  #   0.yes?  # => false
  #   1.yes?  # => true
  #   2.yes?  # => false
  #
  # @return [true, false]
  def yes?
    self == 1
  end

  # A number is no if it's 0:
  #
  #   -1.no? # => false
  #   0.no?  # => true
  #   1.no?  # => false
  #
  # @return [true, false]
  def no?
    zero?
  end
end
