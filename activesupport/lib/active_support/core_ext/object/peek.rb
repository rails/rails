class Object
  # Call +#tap+ on the object, then print out the inspect version of the object to your standard
  # output. This is the shortcut for: +object.tap { |o| puts o.inspect }+
  def peek
    tap { |object| puts object.inspect }
  end
end
