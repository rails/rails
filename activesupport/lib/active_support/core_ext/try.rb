class Object
  # Tries to send the method only if object responds to it. Return +nil+ otherwise.
  # It will also forward any arguments and/or block like Object#send does.
  #
  # ==== Examples
  #
  # Without try
  #   @person && @person.name
  # or
  #   @person ? @person.name : nil
  #
  # With try
  #   @person.try(:name)
  #
  # Try also accepts arguments/blocks for the method it is trying
  #   Person.try(:find, 1)
  #   @people.try(:collect) {|p| p.name}
  #--
  # This method def is for rdoc only. The alias_method below overrides it as an optimization.
  def try(method, *args, &block)
    send(method, *args, &block)
  end
  alias_method :try, :__send__
end

class NilClass
  def try(*args)
    nil
  end
end
