# :markup: markdown
# frozen_string_literal: true

class Array
  # Wraps its argument in an array unless it is already an array (or array-like).
  #
  # Specifically:
  #
  # * If the argument is `nil` an empty array is returned.
  # * Otherwise, if the argument responds to `to_ary` it is invoked, and its result returned.
  # * Otherwise, returns an array with the argument as its single element.
  #
  #         Array.wrap(nil)       # => []
  #         Array.wrap([1, 2, 3]) # => [1, 2, 3]
  #         Array.wrap(0)         # => [0]
  #
  # This method is similar in purpose to `Kernel#Array`, but there are some differences:
  #
  # * If the argument responds to `to_ary` the method is invoked. `Kernel#Array`
  #   moves on to try `to_a` if the returned value is `nil`, but `Array.wrap` returns
  #   an array with the argument as its single element right away.
  # * If the returned value from `to_ary` is neither `nil` nor an `Array` object, `Kernel#Array`
  #   raises an exception, while `Array.wrap` does not, it just returns the value.
  # * It does not call `to_a` on the argument, if the argument does not respond to `to_ary`
  #   it returns an array with the argument as its single element.
  #
  # The last point is easily explained with some enumerables:
  #
  # ```
  # Array(foo: :bar)      # => [[:foo, :bar]]
  # Array.wrap(foo: :bar) # => [{:foo=>:bar}]
  # ```
  #
  # There's also a related idiom that uses the splat operator:
  #
  # ```
  # [*object]
  # ```
  #
  # which returns `[]` for `nil`, but calls to `Array(object)` otherwise.
  #
  # The differences with `Kernel#Array` explained above
  # apply to the rest of `object`s.
  def self.wrap(object)
    if object.nil?
      []
    elsif object.respond_to?(:to_ary)
      object.to_ary || [object]
    else
      [object]
    end
  end
end
