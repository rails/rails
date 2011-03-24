require "cases/helper"
require 'models/mass_assignment_specific'

class MassAssignmentSecurityTest < ActiveModel::TestCase

  def test_attribute_protection
    user = User.new
    expected = { "name" => "John Smith", "email" => "john@smith.com" }
    sanitized = user.sanitize_for_mass_assignment(expected.merge("admin" => true))
    assert_equal expected, sanitized
  end

  def test_attributes_accessible
    user = Person.new
    expected = { "name" => "John Smith", "email" => "john@smith.com" }
    sanitized = user.sanitize_for_mass_assignment(expected.merge("super_powers" => true))
    assert_equal expected, sanitized
  end

  def test_attributes_protected_by_default
    firm = Firm.new
    expected = { }
    sanitized = firm.sanitize_for_mass_assignment({ "type" => "Client" })
    assert_equal expected, sanitized
  end

  def test_mass_assignment_protection_inheritance
    assert_blank LoosePerson.accessible_attributes
    assert_equal Set.new([ 'credit_rating', 'administrator']), LoosePerson.protected_attributes

    assert_blank LooseDescendant.accessible_attributes
    assert_equal Set.new([ 'credit_rating', 'administrator', 'phone_number']), LooseDescendant.protected_attributes

    assert_blank LooseDescendantSecond.accessible_attributes
    assert_equal Set.new([ 'credit_rating', 'administrator', 'phone_number', 'name']), LooseDescendantSecond.protected_attributes,
      'Running attr_protected twice in one class should merge the protections'

    assert_blank TightPerson.protected_attributes - TightPerson.attributes_protected_by_default
    assert_equal Set.new([ 'name', 'address' ]), TightPerson.accessible_attributes

    assert_blank TightDescendant.protected_attributes - TightDescendant.attributes_protected_by_default
    assert_equal Set.new([ 'name', 'address', 'phone_number' ]), TightDescendant.accessible_attributes
  end

  def test_mass_assignment_multiparameter_protector
    task = Task.new
    attributes = { "starting(1i)" => "2004", "starting(2i)" => "6", "starting(3i)" => "24" }
    sanitized = task.sanitize_for_mass_assignment(attributes)
    assert_equal sanitized, { }
  end

end
