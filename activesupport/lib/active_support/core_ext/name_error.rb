
# Add a +missing_name+ method to NameError instances.
class NameError < StandardError
  
  # Add a method to obtain the missing name from a NameError.
  def missing_name
    $1 if /((::)?([A-Z]\w*)(::[A-Z]\w*)*)$/ =~ message
  end
  
  # Was this exception raised because the given name was missing?
  def missing_name?(name)
    if name.is_a? Symbol
      last_name = (missing_name || '').split('::').last
      last_name == name.to_s
    else
      missing_name == name.to_s
    end
  end
  
end