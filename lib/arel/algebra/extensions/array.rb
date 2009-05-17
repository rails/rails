class Array
  def to_hash
    Hash[*flatten]
  end
end