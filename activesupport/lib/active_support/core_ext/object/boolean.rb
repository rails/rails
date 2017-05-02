class Object
  # Only true and false is boolean.
  def boolean?
    false
  end
end

class TrueClass
  def boolean?
    true
  end
end

class FalseClass
  def boolean?
    true
  end
end
