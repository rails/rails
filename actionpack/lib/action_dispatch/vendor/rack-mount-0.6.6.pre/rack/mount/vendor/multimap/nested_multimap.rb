require 'multimap'

# NestedMultimap allows values to be assoicated with a nested
# set of keys.
class NestedMultimap < Multimap
  # call-seq:
  #   multimap[*keys] = value      => value
  #   multimap.store(*keys, value) => value
  #
  # Associates the value given by <i>value</i> with multiple key
  # given by <i>keys</i>.
  #
  #   map = NestedMultimap.new
  #   map["a"] = 100
  #   map["a", "b"] = 101
  #   map["a"] = 102
  #   map   #=> {"a"=>{"b"=>[100, 101, 102], default => [100, 102]}}
  def store(*args)
    keys  = args
    value = args.pop

    raise ArgumentError, 'wrong number of arguments (1 for 2)' unless value

    if keys.length > 1
      update_container(keys.shift) do |container|
        container = self.class.new(container) unless container.is_a?(self.class)
        container[*keys] = value
        container
      end
    elsif keys.length == 1
      super(keys.first, value)
    else
      self << value
    end
  end
  alias_method :[]=, :store

  # call-seq:
  #   multimap << obj  => multimap
  #
  # Pushes the given object on to the end of all the containers.
  #
  #   map = NestedMultimap["a" => [100], "b" => [200, 300]]
  #   map << 300
  #   map["a"] #=> [100, 300]
  #   map["c"] #=> [300]
  def <<(value)
    @hash.each_value { |container| container << value }
    self.default << value
    self
  end

  # call-seq:
  #   multimap[*keys]               =>  value
  #   multimap[key1, key2, key3]    =>  value
  #
  # Retrieves the <i>value</i> object corresponding to the
  # <i>*keys</i> object.
  def [](*keys)
    i, l, r, k = 0, keys.length, self, self.class
    while r.is_a?(k)
      r = i < l ? r._internal_hash[keys[i]] : r.default
      i += 1
    end
    r
  end

  # call-seq:
  #   multimap.each_association { |key, container| block } => multimap
  #
  # Calls <i>block</i> once for each key/container in <i>map</i>, passing
  # the key and container to the block as parameters.
  #
  #   map = NestedMultimap.new
  #   map["a"] = 100
  #   map["a", "b"] = 101
  #   map["a"] = 102
  #   map["c"] = 200
  #   map.each_association { |key, container| puts "#{key} is #{container}" }
  #
  # <em>produces:</em>
  #
  #   ["a", "b"] is [100, 101, 102]
  #   "c" is [200]
  def each_association
    super() do |key, container|
      if container.respond_to?(:each_association)
        container.each_association do |nested_key, value|
          yield [key, nested_key].flatten, value
        end
      else
        yield key, container
      end
    end
  end

  # call-seq:
  #   multimap.each_container_with_default { |container| block } => map
  #
  # Calls <i>block</i> for every container in <i>map</i> including
  # the default, passing the container as a parameter.
  #
  #   map = NestedMultimap.new
  #   map["a"] = 100
  #   map["a", "b"] = 101
  #   map["a"] = 102
  #   map.each_container_with_default { |container| puts container }
  #
  # <em>produces:</em>
  #
  #   [100, 101, 102]
  #   [100, 102]
  #   []
  def each_container_with_default(&block)
    @hash.each_value do |container|
      iterate_over_container(container, &block)
    end
    iterate_over_container(default, &block)
    self
  end

  # call-seq:
  #   multimap.containers_with_default    => array
  #
  # Returns a new array populated with all the containers from
  # <i>map</i> including the default.
  #
  #   map = NestedMultimap.new
  #   map["a"] = 100
  #   map["a", "b"] = 101
  #   map["a"] = 102
  #   map.containers_with_default   #=> [[100, 101, 102], [100, 102], []]
  def containers_with_default
    containers = []
    each_container_with_default { |container| containers << container }
    containers
  end

  def inspect #:nodoc:
    super.gsub(/\}$/, ", default => #{default.inspect}}")
  end

  private
    def iterate_over_container(container)
      if container.respond_to?(:each_container_with_default)
        container.each_container_with_default do |value|
          yield value
        end
      else
        yield container
      end
    end
end

begin
  require 'nested_multimap_ext'
rescue LoadError
end
