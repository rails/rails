module Enumerable
  # Returns a JSON string representing the enumerable. Any +options+
  # given will be passed on to its elements. For example:
  #
  #   users = User.find(:all)
  #   # => users.to_json(:only => :name)
  #
  # will pass the <tt>:only => :name</tt> option to each user.
  def rails_to_json(options = nil) #:nodoc:
    "[#{map { |value| ActiveSupport::JSON.encode(value, options) } * ','}]"
  end
end
