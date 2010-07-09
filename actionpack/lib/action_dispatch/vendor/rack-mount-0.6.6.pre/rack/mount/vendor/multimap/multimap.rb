require 'forwardable'
require 'multiset'

# Multimap is a generalization of a map or associative array
# abstract data type in which more than one value may be associated
# with and returned for a given key.
#
# == Example
#
#   require 'multimap'
#   map = Multimap.new
#   map["a"] = 100
#   map["b"] = 200
#   map["a"] = 300
#   map["a"]                              # -> [100, 300]
#   map["b"]                              # -> [200]
#   map.keys                              # -> #<Multiset: {a, a, b}>
class Multimap
  extend Forwardable

  include Enumerable

  # call-seq:
  #   Multimap[ [key =>|, value]* ]   => multimap
  #
  # Creates a new multimap populated with the given objects.
  #
  #   Multimap["a", 100, "b", 200]       #=> {"a"=>[100], "b"=>[200]}
  #   Multimap["a" => 100, "b" => 200]   #=> {"a"=>[100], "b"=>[200]}
  def self.[](*args)
    default = []

    if args.size == 2 && args.last.is_a?(Hash)
      default = args.shift
    elsif !args.first.is_a?(Hash) && args.size % 2 == 1
      default = args.shift
    end

    if args.size == 1 && args.first.is_a?(Hash)
      args[0] = args.first.inject({}) { |hash, (key, value)|
        unless value.is_a?(default.class)
          value = (default.dup << value)
        end
        hash[key] = value
        hash
      }
    else
      index = 0
      args.map! { |value|
        unless index % 2 == 0 || value.is_a?(default.class)
          value = (default.dup << value)
        end
        index += 1
        value
      }
    end

    map = new
    map.instance_variable_set(:@hash, Hash[*args])
    map.default = default
    map
  end

  # call-seq:
  #   Multimap.new           => multimap
  #   Multimap.new(default)  => multimap
  #
  # Returns a new, empty multimap.
  #
  #   map = Multimap.new(Set.new)
  #   h["a"] = 100
  #   h["b"] = 200
  #   h["a"]           #=> [100].to_set
  #   h["c"]           #=> [].to_set
  def initialize(default = [])
    @hash = Hash.new(default)
  end

  def initialize_copy(original) #:nodoc:
    @hash = Hash.new(original.default.dup)
    original._internal_hash.each_pair do |key, container|
      @hash[key] = container.dup
    end
  end

  def_delegators :@hash, :clear, :default, :default=, :empty?,
                         :fetch, :has_key?, :key?

  # Retrieves the <i>value</i> object corresponding to the
  # <i>*keys</i> object.
  def [](key)
    @hash[key]
  end

  # call-seq:
  #   map[key] = value        => value
  #   map.store(key, value)   => value
  #
  # Associates the value given by <i>value</i> with the key
  # given by <i>key</i>. Unlike a regular hash, multiple can be
  # assoicated with the same value.
  #
  #   map = Multimap["a" => 100, "b" => 200]
  #   map["a"] = 9
  #   map["c"] = 4
  #   map   #=> {"a" => [100, 9], "b" => [200], "c" => [4]}
  def store(key, value)
    update_container(key) do |container|
      container << value
      container
    end
  end
  alias_method :[]=, :store

  # call-seq:
  #   map.delete(key, value)  => value
  #   map.delete(key)         => value
  #
  # Deletes and returns a key-value pair from <i>map</i>. If only
  # <i>key</i> is given, all the values matching that key will be
  # deleted.
  #
  #   map = Multimap["a" => 100, "b" => [200, 300]]
  #   map.delete("b", 300) #=> 300
  #   map.delete("a")      #=> [100]
  def delete(key, value = nil)
    if value
      @hash[key].delete(value)
    else
      @hash.delete(key)
    end
  end

  # call-seq:
  #   map.each { |key, value| block } => map
  #
  # Calls <i>block</i> for each key/value pair in <i>map</i>, passing
  # the key and value to the block as a two-element array.
  #
  #   map = Multimap["a" => 100, "b" => [200, 300]]
  #   map.each { |key, value| puts "#{key} is #{value}" }
  #
  # <em>produces:</em>
  #
  #   a is 100
  #   b is 200
  #   b is 300
  def each
    each_pair do |key, value|
      yield [key, value]
    end
  end

  # call-seq:
  #   map.each_association { |key, container| block } => map
  #
  # Calls <i>block</i> once for each key/container in <i>map</i>, passing
  # the key and container to the block as parameters.
  #
  #   map = Multimap["a" => 100, "b" => [200, 300]]
  #   map.each_association { |key, container| puts "#{key} is #{container}" }
  #
  # <em>produces:</em>
  #
  #   a is [100]
  #   b is [200, 300]
  def each_association(&block)
    @hash.each_pair(&block)
  end

  # call-seq:
  #   map.each_container { |container| block } => map
  #
  # Calls <i>block</i> for each container in <i>map</i>, passing the
  # container as a parameter.
  #
  #   map = Multimap["a" => 100, "b" => [200, 300]]
  #   map.each_container { |container| puts container }
  #
  # <em>produces:</em>
  #
  #   [100]
  #   [200, 300]
  def each_container
    each_association do |_, container|
      yield container
    end
  end

  # call-seq:
  #   map.each_key { |key| block } => map
  #
  # Calls <i>block</i> for each key in <i>hsh</i>, passing the key
  # as a parameter.
  #
  #   map = Multimap["a" => 100, "b" => [200, 300]]
  #   map.each_key { |key| puts key }
  #
  # <em>produces:</em>
  #
  #   a
  #   b
  #   b
  def each_key
    each_pair do |key, _|
      yield key
    end
  end

  # call-seq:
  #   map.each_pair { |key_value_array| block } => map
  #
  # Calls <i>block</i> for each key/value pair in <i>map</i>,
  # passing the key and value as parameters.
  #
  #   map = Multimap["a" => 100, "b" => [200, 300]]
  #   map.each_pair { |key, value| puts "#{key} is #{value}" }
  #
  # <em>produces:</em>
  #
  #   a is 100
  #   b is 200
  #   b is 300
  def each_pair
    each_association do |key, values|
      values.each do |value|
        yield key, value
      end
    end
  end

  # call-seq:
  #   map.each_value { |value| block } => map
  #
  # Calls <i>block</i> for each key in <i>map</i>, passing the
  # value as a parameter.
  #
  #   map = Multimap["a" => 100, "b" => [200, 300]]
  #   map.each_value { |value| puts value }
  #
  # <em>produces:</em>
  #
  #   100
  #   200
  #   300
  def each_value
    each_pair do |_, value|
      yield value
    end
  end

  def ==(other) #:nodoc:
    case other
    when Multimap
      @hash == other._internal_hash
    else
      @hash == other
    end
  end

  def eql?(other) #:nodoc:
    case other
    when Multimap
      @hash.eql?(other._internal_hash)
    else
      @hash.eql?(other)
    end
  end

  def freeze #:nodoc:
    each_container { |container| container.freeze }
    default.freeze
    super
  end

  # call-seq:
  #   map.has_value?(value)    => true or false
  #   map.value?(value)        => true or false
  #
  # Returns <tt>true</tt> if the given value is present for any key
  # in <i>map</i>.
  #
  #   map = Multimap["a" => 100, "b" => [200, 300]]
  #   map.has_value?(300)   #=> true
  #   map.has_value?(999)   #=> false
  def has_value?(value)
    values.include?(value)
  end
  alias_method :value?, :has_value?

  # call-seq:
  #   map.index(value)    => key
  #
  # Returns the key for a given value. If not found, returns
  # <tt>nil</tt>.
  #
  #   map = Multimap["a" => 100, "b" => [200, 300]]
  #   map.index(100)   #=> "a"
  #   map.index(200)   #=> "b"
  #   map.index(999)   #=> nil
  def index(value)
    invert[value]
  end

  # call-seq:
  #   map.delete_if {| key, value | block }  -> map
  #
  # Deletes every key-value pair from <i>map</i> for which <i>block</i>
  # evaluates to <code>true</code>.
  #
  #   map = Multimap["a" => 100, "b" => [200, 300]]
  #   map.delete_if {|key, value| value >= 300 }
  #     #=> Multimap["a" => 100, "b" => 200]
  #
  def delete_if
    each_association do |key, container|
      container.delete_if do |value|
        yield [key, value]
      end
    end
    self
  end

  # call-seq:
  #   map.reject {| key, value | block }  -> map
  #
  # Same as <code>Multimap#delete_if</code>, but works on (and returns) a
  # copy of the <i>map</i>. Equivalent to
  # <code><i>map</i>.dup.delete_if</code>.
  #
  def reject(&block)
    dup.delete_if(&block)
  end

  # call-seq:
  #   map.reject! {| key, value | block }  -> map or nil
  #
  # Equivalent to <code>Multimap#delete_if</code>, but returns
  # <code>nil</code> if no changes were made.
  #
  def reject!(&block)
    old_size = size
    delete_if(&block)
    old_size == size ? nil : self
  end

  # call-seq:
  #   map.replace(other_map) => map
  #
  # Replaces the contents of <i>map</i> with the contents of
  # <i>other_map</i>.
  #
  #   map = Multimap["a" => 100, "b" => 200]
  #   map.replace({ "c" => 300, "d" => 400 })
  #   #=> Multimap["c" => 300, "d" => 400]
  def replace(other)
    case other
    when Array
      @hash.replace(self.class[self.default, *other])
    when Hash
      @hash.replace(self.class[self.default, other])
    when self.class
      @hash.replace(other)
    else
      raise ArgumentError
    end
  end

  # call-seq:
  #   map.invert => multimap
  #
  # Returns a new multimap created by using <i>map</i>'s values as keys,
  # and the keys as values.
  #
  #   map = Multimap["n" => 100, "m" => 100, "d" => [200, 300]]
  #   map.invert #=> Multimap[100 => ["n", "m"], 200 => "d", 300 => "d"]
  def invert
    h = self.class.new(default.dup)
    each_pair { |key, value| h[value] = key }
    h
  end

  # call-seq:
  #   map.keys    => multiset
  #
  # Returns a new +Multiset+ populated with the keys from this hash. See also
  # <tt>Multimap#values</tt> and <tt>Multimap#containers</tt>.
  #
  #   map = Multimap["a" => 100, "b" => [200, 300], "c" => 400]
  #   map.keys   #=> Multiset.new(["a", "b", "b", "c"])
  def keys
    keys = Multiset.new
    each_key { |key| keys << key }
    keys
  end

  # Returns true if the given key is present in Multimap.
  def include?(key)
    keys.include?(key)
  end
  alias_method :member?, :include?

  # call-seq:
  #   map.length    =>  fixnum
  #   map.size      =>  fixnum
  #
  # Returns the number of key-value pairs in the map.
  #
  #   map = Multimap["a" => 100, "b" => [200, 300], "c" => 400]
  #   map.length        #=> 4
  #   map.delete("a")   #=> 100
  #   map.length        #=> 3
  def size
    values.size
  end
  alias_method :length, :size

  # call-seq:
  #   map.merge(other_map) => multimap
  #
  # Returns a new multimap containing the contents of <i>other_map</i> and
  # the contents of <i>map</i>.
  #
  #   map1 = Multimap["a" => 100, "b" => 200]
  #   map2 = Multimap["a" => 254, "c" => 300]
  #   map2.merge(map2) #=> Multimap["a" => 100, "b" => [200, 254], "c" => 300]
  #   map1             #=> Multimap["a" => 100, "b" => 200]
  def merge(other)
    dup.update(other)
  end

  # call-seq:
  #   map.merge!(other_map)    => multimap
  #   map.update(other_map)    => multimap
  #
  # Adds each pair from <i>other_map</i> to <i>map</i>.
  #
  #   map1 = Multimap["a" => 100, "b" => 200]
  #   map2 = Multimap["b" => 254, "c" => 300]
  #
  #   map1.merge!(map2)
  #   #=> Multimap["a" => 100, "b" => [200, 254], "c" => 300]
  def update(other)
    case other
    when self.class
      other.each_pair { |key, value| store(key, value) }
    when Hash
      update(self.class[self.default, other])
    else
      raise ArgumentError
    end
    self
  end
  alias_method :merge!, :update

  # call-seq:
  #   map.select { |key, value| block }   => multimap
  #
  # Returns a new Multimap consisting of the pairs for which the
  # block returns true.
  #
  #   map = Multimap["a" => 100, "b" => 200, "c" => 300]
  #   map.select { |k,v| k > "a" }  #=> Multimap["b" => 200, "c" => 300]
  #   map.select { |k,v| v < 200 }  #=> Multimap["a" => 100]
  def select
    inject(self.class.new) { |map, (key, value)|
      map[key] = value if yield([key, value])
      map
    }
  end

  # call-seq:
  #   map.to_a => array
  #
  # Converts <i>map</i> to a nested array of [<i>key,
  # value</i>] arrays.
  #
  #   map = Multimap["a" => 100, "b" => [200, 300], "c" => 400]
  #   map.to_a   #=> [["a", 100], ["b", 200], ["b", 300], ["c", 400]]
  def to_a
    ary = []
    each_pair do |key, value|
      ary << [key, value]
    end
    ary
  end

  # call-seq:
  #   map.to_hash => hash
  #
  # Converts <i>map</i> to a basic hash.
  #
  #   map = Multimap["a" => 100, "b" => [200, 300]]
  #   map.to_hash   #=> { "a" => [100], "b" => [200, 300] }
  def to_hash
    @hash.dup
  end

  # call-seq:
  #   map.containers    => array
  #
  # Returns a new array populated with the containers from <i>map</i>. See
  # also <tt>Multimap#keys</tt> and <tt>Multimap#values</tt>.
  #
  #   map = Multimap["a" => 100, "b" => [200, 300]]
  #   map.containers   #=> [[100], [200, 300]]
  def containers
    containers = []
    each_container { |container| containers << container }
    containers
  end

  # call-seq:
  #   map.values    => array
  #
  # Returns a new array populated with the values from <i>map</i>. See
  # also <tt>Multimap#keys</tt> and <tt>Multimap#containers</tt>.
  #
  #   map = Multimap["a" => 100, "b" => [200, 300]]
  #   map.values   #=> [100, 200, 300]
  def values
    values = []
    each_value { |value| values << value }
    values
  end

  # Return an array containing the values associated with the given keys.
  def values_at(*keys)
    @hash.values_at(*keys)
  end

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
        map.add('__default__', @hash.default)
      end
    end
  end

  def yaml_initialize(tag, val) #:nodoc:
    default = val.delete('__default__')
    @hash = val
    @hash.default = default
    self
  end

  protected
    def _internal_hash #:nodoc:
      @hash
    end

    def update_container(key) #:nodoc:
      container = @hash[key]
      container = container.dup if container.equal?(default)
      container = yield(container)
      @hash[key] = container
    end
end
