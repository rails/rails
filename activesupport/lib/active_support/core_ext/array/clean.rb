# encoding: utf-8

class Array
  # Returns an array with nil and blank values removed.
  # Nested arrays are also cleaned.
  #
  # Example
  #
  #   [1, 2, nil, "", 3, [4, 5, nil]].clean # => [1, 2, 3, [4, 5]]
  #
  def clean
    dup.clean!
  end

  def clean!
    reject! do |value|
      if value.is_a?(Array)
        value.clean!
        value.blank?
      else
        value.is_a?(FalseClass) ? false : value.blank?
      end
    end
    self
  end
end
