class NameError
  # Extract the name of the missing constant from the exception message.
  #
  #   begin
  #     HelloWorld
  #   rescue NameError => e
  #     e.missing_name
  #   end
  #   # => "HelloWorld"
  def missing_name
    if /undefined local variable or method/ !~ message
      $1 if /((::)?([A-Z]\w*)(::[A-Z]\w*)*)$/ =~ message
    end
  end

  # Was this exception raised because the given name was missing?
  #
  #   begin
  #     HelloWorld
  #   rescue NameError => e
  #     e.missing_name?("HelloWorld")
  #   end
  #   # => true
  def missing_name?(name)
    if name.is_a? Symbol
      self.name == name
    else
      missing_name == name.to_s
    end
  end
end
