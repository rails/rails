class Hash
  # Invokes the block once for each pair of self recursively,
  # replacing the pair's value with the value returned by block.
  #
  # Examples:
  #
  #   {:a => 2}.deep_map! { |k,v| v * 2 }                     # => {:a => 4}
  #   {:a => {:b => 3}}.deep_map! { |k,v| v + 2 }             # => {:a => {:b => 5}}
  #   {1 => {2 => "a"}}.deep_map! { |k,v| v + "!" }           # => {1 => {2 => "a!"}}
  #   {1 => {2 => ["a"]}, 3=>1 }.deep_map! { |k,v| v * 2  }   # => {1 => {2 => ["a", "a"]}, 3 => 2}
  def deep_map!( &block )
    self.each_pair do |k,v|
      tv = self[k]
      self[k] = tv.is_a?(Hash) && v.is_a?(Hash) ? tv.deep_map!(&block) : block.call( [k, v] )
    end
    self
  end
end
