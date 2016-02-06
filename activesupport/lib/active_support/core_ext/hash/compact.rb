class Hash
  # Returns a hash with non +nil+ values.
  #
  #   hash = { a: true, b: false, c: nil}
  #   hash.compact # => { a: true, b: false}
  #   hash # => { a: true, b: false, c: nil}
  #   { c: nil }.compact # => {}
  def compact
    self.select { |_, value| !value.nil? }
  end

  # Replaces current hash with non +nil+ values.
  #
  #   hash = { a: true, b: false, c: nil}
  #   hash.compact! # => { a: true, b: false}
  #   hash # => { a: true, b: false}
  def compact!
    self.reject! { |_, value| value.nil? }
  end

  # Returns a hash with non +blank+ values.
  #
  #   hash = { a: true, b: false, c: nil, d: [], e: {}, f: ''}
  #   hash.force_compact # => { a: true}
  #   hash # => { a: true, b: false, c: nil, d: [], e: {}, f: ''}
  #   { b: false, c: nil, d: [], e: {}, f: '' }.force_compact # => {}
  def force_compact
    self.select { |_, value| !value.blank? }
  end

  # Replaces current hash with non +blank+ values.
  #
  #   hash = { a: true, b: false, c: nil, d: [], e: {}, f: ''}
  #   hash.force_compact! # => { a: true}
  #   hash # => { a: true}
  def force_compact!
    self.reject! { |_, value| value.blank? }
  end
end
