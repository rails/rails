
class AssignmentSafetyTest < ActiveModel::TestCase

  def test_assignment_safe_hash
    user = User.new
    attributes = { "name" => "John Smith", "email" => "john@smith.com", "admin" => true }.assignment_safe
    assert_equal attributes, user.sanitize_for_mass_assignment(attributes)
  end

  def test_hash_assignment_safe_property
    assert_safe(safe_hash)
    assert_not_safe(unsafe_hash)
    attributes = {}
    assert_not_equal attributes.object_id,  attributes.assignment_safe
  end


  def test_merge

    assert_not_safe(safe_hash.merge(unsafe_hash))
    assert_not_safe(safe_hash.merge!(unsafe_hash))
    assert_not_safe({}.merge(safe_hash))
    assert_not_safe({}.merge!(safe_hash))

    assert_safe(safe_hash.merge(safe_hash))
    assert_safe(safe_hash.merge!(safe_hash))

  end

  def test_update
    assert_not_safe(safe_hash.update(unsafe_hash))
    assert_not_safe({}.update(safe_hash))
  end

  protected 

  def safe_hash
    {}.assignment_safe
  end

  def unsafe_hash
    {}
  end

  def assert_safe(hash)
    assert hash.assignment_safe?
  end
  def assert_not_safe(hash)
    assert !hash.assignment_safe?
  end
end
