class Array
  # Wraps the object in an Array unless it's an Array.  Converts the
  # object to an Array using #to_ary if it implements that.
  def self.wrap(object)
    if object.nil?
      []
    # to_a doesn't work correctly with Array() but to_ary always does
    elsif object.respond_to?(:to_a) && !object.respond_to?(:to_ary)
      [object]
    else
      Array(object)
    end
  end
end
