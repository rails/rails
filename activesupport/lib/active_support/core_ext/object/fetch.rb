class Object
  # Invokes the method and pass the arguments if object respond to it, if not returns
  # the last argument if present, otherwise return nil
  #
  # ==== Examples
  #
  # Without +fetch+
  #   @person.respond_to?(:to_model) ? @person.to_model : @person
  #
  # With +fetch+
  #   @person.fetch(:to_model, @person)
  #
  # +fetch+ also accepts arguments for the method
  #   Person.fetch(:find, 1, 'not find')
  def fetch(method, *args)
    default = args.pop || nil
    respond_to?(method) ? __send__(method, *args) : default
  end
end