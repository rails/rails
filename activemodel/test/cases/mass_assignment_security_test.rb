require "cases/helper"
require 'models/mass_assignment_specific'


class CustomSanitizer < ActiveModel::MassAssignmentSecurity::Sanitizer

  def process_removed_attributes(klass, attrs)
    raise StandardError
  end

end

class MassAssignmentSecurityTest < ActiveModel::TestCase
  def test_attribute_protection
    user = User.new
    expected = { "name" => "John Smith", "email" => "john@smith.com" }
    sanitized = user.sanitize_for_mass_assignment(expected.merge("admin" => true))
    assert_equal expected, sanitized
  end

  def test_attribute_protection_when_role_is_nil
    user = User.new
    expected = { "name" => "John Smith", "email" => "john@smith.com" }
    sanitized = user.sanitize_for_mass_assignment(expected.merge("admin" => true), nil)
    assert_equal expected, sanitized
  end

  def test_only_moderator_role_attribute_accessible
    user = SpecialUser.new
    expected = { "name" => "John Smith", "email" => "john@smith.com" }
    sanitized = user.sanitize_for_mass_assignment(expected.merge("admin" => true), :moderator)
    assert_equal expected, sanitized

    sanitized = user.sanitize_for_mass_assignment({ "name" => "John Smith", "email" => "john@smith.com", "admin" => true })
    assert_equal({}, sanitized)
  end

  def test_attributes_accessible
    user = Person.new
    expected = { "name" => "John Smith", "email" => "john@smith.com" }
    sanitized = user.sanitize_for_mass_assignment(expected.merge("admin" => true))
    assert_equal expected, sanitized
  end

  def test_attributes_accessible_with_admin_role
    user = Person.new
    expected = { "name" => "John Smith", "email" => "john@smith.com", "admin" => true }
    sanitized = user.sanitize_for_mass_assignment(expected.merge("super_powers" => true), :admin)
    assert_equal expected, sanitized
  end

  def test_attributes_accessible_with_roles_given_as_array
    user = Account.new
    expected = { "name" => "John Smith", "email" => "john@smith.com" }
    sanitized = user.sanitize_for_mass_assignment(expected.merge("admin" => true))
    assert_equal expected, sanitized
  end

  def test_attributes_accessible_with_admin_role_when_roles_given_as_array
    user = Account.new
    expected = { "name" => "John Smith", "email" => "john@smith.com", "admin" => true }
    sanitized = user.sanitize_for_mass_assignment(expected.merge("super_powers" => true), :admin)
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
    assert_equal Set.new(['credit_rating', 'administrator']), LoosePerson.protected_attributes

    assert_blank LoosePerson.accessible_attributes
    assert_equal Set.new(['credit_rating']), LoosePerson.protected_attributes(:admin)

    assert_blank LooseDescendant.accessible_attributes
    assert_equal Set.new(['credit_rating', 'administrator', 'phone_number']), LooseDescendant.protected_attributes

    assert_blank LooseDescendantSecond.accessible_attributes
    assert_equal Set.new(['credit_rating', 'administrator', 'phone_number', 'name']), LooseDescendantSecond.protected_attributes,
      'Running attr_protected twice in one class should merge the protections'

    assert_blank TightPerson.protected_attributes - TightPerson.attributes_protected_by_default
    assert_equal Set.new(['name', 'address']), TightPerson.accessible_attributes

    assert_blank TightPerson.protected_attributes(:admin) - TightPerson.attributes_protected_by_default
    assert_equal Set.new(['name', 'address', 'admin']), TightPerson.accessible_attributes(:admin)

    assert_blank TightDescendant.protected_attributes - TightDescendant.attributes_protected_by_default
    assert_equal Set.new(['name', 'address', 'phone_number']), TightDescendant.accessible_attributes

    assert_blank TightDescendant.protected_attributes(:admin) - TightDescendant.attributes_protected_by_default
    assert_equal Set.new(['name', 'address', 'admin', 'super_powers']), TightDescendant.accessible_attributes(:admin)
  end

  def test_mass_assignment_multiparameter_protector
    task = Task.new
    attributes = { "starting(1i)" => "2004", "starting(2i)" => "6", "starting(3i)" => "24" }
    sanitized = task.sanitize_for_mass_assignment(attributes)
    assert_equal sanitized, { }
  end

  def test_custom_sanitizer
    old_sanitizer = User._mass_assignment_sanitizer

    user = User.new
    User.mass_assignment_sanitizer = CustomSanitizer.new
    assert_raise StandardError do
      user.sanitize_for_mass_assignment("admin" => true)
    end
  ensure
    User.mass_assignment_sanitizer = old_sanitizer
  end
end