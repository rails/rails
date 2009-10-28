class Array
  # Wraps the object in an Array unless it's an Array.  Converts the
  # object to an Array using #to_ary if it implements that.
  array = Array("foo\nbar")

  if array.size == 1
    def self.wrap(object)
      Array(object)
    end
  else
    def self.wrap(object)
      if object.is_a?(String)
        [object]
      else
        Array(object)
      end
    end
  end
end
