require 'set'

# Multiset implements a collection of unordered values and
# allows duplicates.
#
# == Example
#
#   require 'multiset'
#   s1 = Multiset.new [1, 2]              # -> #<Multiset: {1, 2}>
#   s1.add(2)                             # -> #<Multiset: {1, 2, 2}>
#   s1.merge([2, 6])                      # -> #<Multiset: {1, 2, 2, 2, 3}>
#   s1.multiplicity(2)                    # -> 3
#   s1.multiplicity(3)                    # -> 1
class Multiset < Set
  def initialize(*args, &block) #:nodoc:
    @hash = Hash.new(0)
    super
  end

  # Returns the number of times an element belongs to the multiset.
  def multiplicity(e)
    @hash[e]
  end

  # Returns the total number of elements in a multiset, including
  # repeated memberships
  def cardinality
    @hash.inject(0) { |s, (e, m)| s += m }
  end
  alias_method :size, :cardinality
  alias_method :length, :cardinality

  # Converts the set to an array. The order of elements is uncertain.
  def to_a
    inject([]) { |ary, (key, _)| ary << key }
  end

  # Returns true if the set is a superset of the given set.
  def superset?(set)
    set.is_a?(self.class) or raise ArgumentError, "value must be a set"
    return false if cardinality < set.cardinality
    set.all? { |o| set.multiplicity(o) <= multiplicity(o) }
  end

  # Returns true if the set is a proper superset of the given set.
  def proper_superset?(set)
    set.is_a?(self.class) or raise ArgumentError, "value must be a set"
    return false if cardinality <= set.cardinality
    set.all? { |o| set.multiplicity(o) <= multiplicity(o) }
  end

  # Returns true if the set is a subset of the given set.
  def subset?(set)
    set.is_a?(self.class) or raise ArgumentError, "value must be a set"
    return false if set.cardinality < cardinality
    all? { |o| multiplicity(o) <= set.multiplicity(o) }
  end

  # Returns true if the set is a proper subset of the given set.
  def proper_subset?(set)
    set.is_a?(self.class) or raise ArgumentError, "value must be a set"
    return false if set.cardinality <= cardinality
    all? { |o| multiplicity(o) <= set.multiplicity(o) }
  end

  # Calls the given block once for each element in the set, passing
  # the element as parameter. Returns an enumerator if no block is
  # given.
  def each
    @hash.each_pair do |key, multiplicity|
      multiplicity.times do
        yield(key)
      end
    end
    self
  end

  # Adds the given object to the set and returns self. Use +merge+ to
  # add many elements at once.
  def add(o)
    @hash[o] ||= 0
    @hash[o] += 1
    self
  end
  alias << add

  undef :add?

  # Deletes all the identical object from the set and returns self.
  # If +n+ is given, it will remove that amount of identical objects
  # from the set. Use +subtract+ to delete many different items at
  # once.
  def delete(o, n = nil)
    if n
      @hash[o] ||= 0
      @hash[o] -= n if @hash[o] > 0
      @hash.delete(o) if @hash[o] == 0
    else
      @hash.delete(o)
    end
    self
  end

  undef :delete?

  # Deletes every element of the set for which block evaluates to
  # true, and returns self.
  def delete_if
    each { |o| delete(o) if yield(o) }
    self
  end

  # Merges the elements of the given enumerable object to the set and
  # returns self.
  def merge(enum)
    enum.each { |o| add(o) }
    self
  end

  # Deletes every element that appears in the given enumerable object
  # and returns self.
  def subtract(enum)
    enum.each { |o| delete(o, 1) }
    self
  end

  # Returns a new set containing elements common to the set and the
  # given enumerable object.
  def &(enum)
    s = dup
    n = self.class.new
    enum.each { |o|
      if s.include?(o)
        s.delete(o, 1)
        n.add(o)
      end
    }
    n
  end
  alias intersection &

  # Returns a new set containing elements exclusive between the set
  # and the given enumerable object.  (set ^ enum) is equivalent to
  # ((set | enum) - (set & enum)).
  def ^(enum)
    n = self.class.new(enum)
    each { |o| n.include?(o) ? n.delete(o, 1) : n.add(o) }
    n
  end

  # Returns true if two sets are equal. Two multisets are equal if
  # they have the same cardinalities and each element has the same
  # multiplicity in both sets. The equality of each element inside
  # the multiset is defined according to Object#eql?.
  def eql?(set)
    return true if equal?(set)
    set = self.class.new(set) unless set.is_a?(self.class)
    return false unless cardinality == set.cardinality
    superset?(set) && subset?(set)
  end
  alias_method :==, :eql?

  def marshal_dump #:nodoc:
    @hash
  end

  def marshal_load(hash) #:nodoc:
    @hash = hash
  end

  def to_yaml(opts = {}) #:nodoc:
    YAML::quick_emit(self, opts) do |out|
      out.map(taguri, to_yaml_style) do |map|
        @hash.each do |k, v|
          map.add(k, v)
        end
      end
    end
  end

  def yaml_initialize(tag, val) #:nodoc:
    @hash = val
    self
  end
end
