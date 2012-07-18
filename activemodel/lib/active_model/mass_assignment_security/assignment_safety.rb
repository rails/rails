class Hash

  def assignment_safe?
    false
  end

  def assignment_safe
    ActiveModel::MassAssignmentSecurity::SafeHash.new.replace(self)
  end
end


class ActiveModel::MassAssignmentSecurity::SafeHash < Hash

  def initialize(*)
    super
    @assignment_safe = true
  end

  def assignment_safe?
    @assignment_safe
  end

  def assignment_safe=(value)
    @assignment_safe = value
  end

  def merge(other)
    result = super
    result.assignment_safe = false unless other.assignment_safe?
    result
  end

  def merge!(other)
    super
    @assignment_safe = false unless other.assignment_safe?
    self
  end

  alias update merge!

end
