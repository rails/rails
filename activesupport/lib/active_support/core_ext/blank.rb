# The methods here are provided to speed up function blank? in class Object
class NilClass
  def blank?
    true
  end
end

class FalseClass
  def blank?
    true
  end
end

class TrueClass
  def blank?
    false
  end
end

class Array
  alias_method :blank?, :empty?
end

class Hash
  alias_method :blank?, :empty?
end

class String
  def blank?
    empty? || strip.empty?
  end
end

class Numeric
  alias_method :blank?, :zero?
end