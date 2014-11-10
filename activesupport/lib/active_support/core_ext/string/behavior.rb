class String
  # Enable more predictable duck-typing on String-like classes. See <tt>Object#acts_like?</tt>.
  def acts_like?(duck_type)
    duck_type == :string
  end
end
