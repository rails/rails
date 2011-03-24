class Range
  alias_method(:cover?, :include?) unless instance_methods.include?(:cover?)
end
