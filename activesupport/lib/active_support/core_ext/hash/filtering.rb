# frozen_string_literal: true

# Extensions to Hash for filtering by key/value predicates.
#
# Examples:
#   { a: "", b: 1, c: nil }.reject_if_value(:blank?)
#   # => { b: 1 }
#
#   { "x" => 1, "y" => 2 }.select_if_key(:start_with?, "x")
#   # => { "x" => 1 }
#
#   { a: 1, b: 2, c: 3 }.reject_if_value(->(v) { v > 2 })
#   # => { a: 1, b: 2 }
class Hash
  # Returns a new Hash without pairs whose value satisfies the predicate.
  # The predicate can be:
  # - a Symbol/String method name called on each value, if the value responds to it
  # - a Proc responding to #call
  # - a block
  def reject_if_value(condition = nil, *args, &block)
    predicate = __as_hash_filter_predicate(condition, args, &block)
    reject { |_k, v| predicate.call(v) }
  end

  # Returns a new Hash keeping only pairs whose value satisfies the predicate.
  def select_if_value(condition = nil, *args, &block)
    predicate = __as_hash_filter_predicate(condition, args, &block)
    select { |_k, v| predicate.call(v) }
  end

  # Returns a new Hash without pairs whose key satisfies the predicate.
  def reject_if_key(condition = nil, *args, &block)
    predicate = __as_hash_filter_predicate(condition, args, &block)
    reject { |k, _v| predicate.call(k) }
  end

  # Returns a new Hash keeping only pairs whose key satisfies the predicate.
  def select_if_key(condition = nil, *args, &block)
    predicate = __as_hash_filter_predicate(condition, args, &block)
    select { |k, _v| predicate.call(k) }
  end

  # Removes pairs whose value satisfies the predicate and returns self.
  # Always returns self (never nil).
  def reject_if_value!(condition = nil, *args, &block)
    predicate = __as_hash_filter_predicate(condition, args, &block)
    delete_if { |_k, v| predicate.call(v) }
  end

  # Keeps only pairs whose value satisfies the predicate and returns self.
  # Always returns self (never nil).
  def select_if_value!(condition = nil, *args, &block)
    predicate = __as_hash_filter_predicate(condition, args, &block)
    keep_if { |_k, v| predicate.call(v) }
  end

  # Removes pairs whose key satisfies the predicate and returns self.
  # Always returns self (never nil).
  def reject_if_key!(condition = nil, *args, &block)
    predicate = __as_hash_filter_predicate(condition, args, &block)
    delete_if { |k, _v| predicate.call(k) }
  end

  # Keeps only pairs whose key satisfies the predicate and returns self.
  # Always returns self (never nil).
  def select_if_key!(condition = nil, *args, &block)
    predicate = __as_hash_filter_predicate(condition, args, &block)
    keep_if { |k, _v| predicate.call(k) }
  end

  private
    def __as_hash_filter_predicate(condition, args, &block)
      if block
        block
      elsif condition.respond_to?(:call)
        condition
      elsif condition.respond_to?(:to_sym)
        method_name = condition.to_sym
        ->(object) { object.respond_to?(method_name) && object.public_send(method_name, *args) }
      else
        raise ArgumentError, "Provide a predicate via block, callable, or method name"
      end
    end
end
