class Array

  # Checks if the array values ​​of another array
  # [1,2].included_in?([1,2,3]) => true
  # [4,5].included_in?([1,2,3]) => false
  # received_active_record_objects.included_in?(relation_active_record_objects) => works fine, when you needed to validate has-many or many-to-many relations

  def included_in?(array)
    array.to_set.superset?(self.to_set)
  end

end