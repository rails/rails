# frozen_string_literal: true

class Array
  # Smooshes all the elements of an array together into one array
  #
  #   cool_methods = [:forty_two, [:current_user]]
  #
  #   cool_methods.smoosh # => [:forty_two, :current_user]
  def smoosh
    flatten
  end
end
