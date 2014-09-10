# encoding: utf-8

class NilClass
  # +nil+ respond with any args:
  #
  #   nil.to_s(:foo) # => ''
  #
  # @return ['']
  def to_s(*args)
    ''
  end
end
