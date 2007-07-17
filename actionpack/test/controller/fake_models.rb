class Customer < Struct.new(:name, :id)
  def to_param
    id.to_s
  end
end
