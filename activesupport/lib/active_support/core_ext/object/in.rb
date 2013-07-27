class Object
  # Returns true if the object is equal to any of the
  # possibilities specified as parameters.
  #
  # This simplifies:
  #
  #   if params[:subject] == :english || params[:subject] == :math || params[:subject] == :biology
  #
  # ...to:
  #
  #   if params[:subject].in?(:english, :math, :biology)
  #
  def in?(*possibilities)
    possibilities.include?(self)
  end
end