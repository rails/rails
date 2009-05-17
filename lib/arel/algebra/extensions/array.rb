class Array
  def to_hash
    Hash[*flatten]
  end
  
  def group_by
    inject({}) do |groups, element|
      (groups[yield(element)] ||= []) << element
      groups
    end
  end
end