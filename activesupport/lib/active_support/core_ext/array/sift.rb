# frozen_string_literal: true

class Array
  # Returns the object if the object is included in the array.
  #
  #   ["asc", "desc"].sift("asc") # => "asc"
  #   ["day", "month", "year"].sift("century") # => nil
  #
  # This method can be used to filter out unauthorized values from user input:
  #
  #   # Will only allow `"asc"` and `"desc"`, otherwise falling back to `"asc"`
  #   sort_order = ["asc", "desc"].sift(params[:order]) || "asc"
  def sift(object)
    object if !object.nil? && include?(object)
  end
end
