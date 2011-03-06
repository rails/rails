class Hash
  # Merges the caller into +other_hash+. For example,
  #
  #   options = options.reverse_merge(:size => 25, :velocity => 10)
  #
<<<<<<< HEAD
  # The default <tt>:size</tt> and <tt>:velocity</tt> are only set if the +options+ hash passed in doesn't already
  # have the respective key.
  #
  # As contrast, using Ruby's built in <tt>merge</tt> would require writing the following:
  #
  #   def setup(options = {})
  #     options = { :size => 25, :velocity => 10 }.merge(options)
  #   end
=======
  # is equivalent to
  #
  #   options = {:size => 25, :velocity => 10}.merge(options)
  #
  # This is particularly useful for initializing an options hash
  # with default values.
>>>>>>> 20768176292cbcb883ab152b4aa9ed8c664771cd
  def reverse_merge(other_hash)
    other_hash.merge(self)
  end

  # Destructive +reverse_merge+.
  def reverse_merge!(other_hash)
    # right wins if there is no left
    merge!( other_hash ){|key,left,right| left }
  end

  alias_method :reverse_update, :reverse_merge!
end
