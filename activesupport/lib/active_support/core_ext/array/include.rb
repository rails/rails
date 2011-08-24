class Array
  # Improve Array#include? functionality.
  # You can pass 2 or more arguments to check they inclusion into array.
  #   
  #  Array#include_all? the same as:
  #
  #  array.include?(a) && array.include?(b) && array.include?(c) ...etc.
  #
  def include_all?(*args)
    args.map{ |i| self.include?(i) }.all?
  end

  #
  #  Array#include_any? the same as:
  #
  #  array.include?(a) || array.include?(b) || array.include?(c) ...etc.
  #
  def include_any?(*args)
    args.map{ |i| self.include?(i) }.any?
  end
end
