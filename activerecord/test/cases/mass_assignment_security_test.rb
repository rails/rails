require "cases/helper"
require 'models/company'
require 'models/subscriber'
require 'models/keyboard'
require 'models/task'
require 'models/person'


module MassAssignmentTestHelpers
  def setup
    # another AR test modifies the columns which causes issues with create calls
    TightPerson.reset_column_information
    LoosePerson.reset_column_information
  end

  def attributes_hash
    {
      :id => 5,
      :first_name => 'Josh',
      :gender   => 'm',
      :comments => 'rides a sweet bike'
    }
  end

  def assert_default_attributes(person, create = false)
    unless create
      assert_nil person.id
    else
      assert !!person.id
    end
    assert_equal 'Josh', person.first_name
    assert_equal 'm',    person.gender
    assert_nil person.comments
  end

  def assert_admin_attributes(person, create = false)
    unless create
      assert_nil person.id
    else
      assert !!person.id
    end
    assert_equal 'Josh', person.first_name
    assert_equal 'm',    person.gender
    assert_equal 'rides a sweet bike', person.comments
  end

  def assert_all_attributes(person)
    assert_equal 5, person.id
    assert_equal 'Josh', person.first_name
    assert_equal 'm',    person.gender
    assert_equal 'rides a sweet bike', person.comments
  end

  def with_strict_sanitizer
    ActiveRecord::Base.mass_assignment_sanitizer = :strict
    yield
  ensure
    ActiveRecord::Base.mass_assignment_sanitizer = :logger
  end
end

module MassAssignmentRelationTestHelpers
  def setup
    super
    @person = LoosePerson.create(attributes_hash)
  end
end


class MassAssignmentSecurityTest < ActiveRecord::TestCase
  include MassAssignmentTestHelpers

  def test_customized_primary_key_remains_protected
    subscriber = Subscriber.new(:nick => 'webster123', :name => 'nice try')
    assert_nil subscriber.id

    keyboard = Keyboard.new(:key_number => 9, :name => 'nice try')
    assert_nil keyboard.id
  end

  def test_customized_primary_key_remains_protected_when_referred_to_as_id
    subscriber = Subscriber.new(:id => 'webster123', :name => 'nice try')
    assert_nil subscriber.id

    keyboard = Keyboard.new(:id => 9, :name => 'nice try')
    assert_nil keyboard.id
  end

  def test_mass_assigning_invalid_attribute
    firm = Firm.new

    assert_raise(ActiveRecord::UnknownAttributeError) do
      firm.attributes = { "id" => 5, "type" => "Client", "i_dont_even_exist" => 20 }
    end
  end

  def test_mass_assigning_does_not_choke_on_nil
    assert_nil Firm.new.assign_attributes(nil)
  end

  def test_mass_assigning_does_not_choke_on_empty_hash
    assert_nil Firm.new.assign_attributes({})
  end

  def test_assign_attributes_uses_default_role_when_no_role_is_provided
    p = LoosePerson.new
    p.assign_attributes(attributes_hash)

    assert_default_attributes(p)
  end

  def test_assign_attributes_skips_mass_assignment_security_protection_when_without_protection_is_used
    p = LoosePerson.new
    p.assign_attributes(attributes_hash, :without_protection => true)

    assert_all_attributes(p)
  end

  def test_assign_attributes_with_default_role_and_attr_protected_attributes
    p = LoosePerson.new
    p.assign_attributes(attributes_hash, :as => :default)

    assert_default_attributes(p)
  end

  def test_assign_attributes_with_admin_role_and_attr_protected_attributes
    p = LoosePerson.new
    p.assign_attributes(attributes_hash, :as => :admin)

    assert_admin_attributes(p)
  end

  def test_assign_attributes_with_default_role_and_attr_accessible_attributes
    p = TightPerson.new
    p.assign_attributes(attributes_hash, :as => :default)

    assert_default_attributes(p)
  end

  def test_assign_attributes_with_admin_role_and_attr_accessible_attributes
    p = TightPerson.new
    p.assign_attributes(attributes_hash, :as => :admin)

    assert_admin_attributes(p)
  end

  def test_new_with_attr_accessible_attributes
    p = TightPerson.new(attributes_hash)

    assert_default_attributes(p)
  end

  def test_new_with_attr_protected_attributes
    p = LoosePerson.new(attributes_hash)

    assert_default_attributes(p)
  end

  def test_create_with_attr_accessible_attributes
    p = TightPerson.create(attributes_hash)

    assert_default_attributes(p, true)
  end

  def test_create_with_attr_protected_attributes
    p = LoosePerson.create(attributes_hash)

    assert_default_attributes(p, true)
  end

  def test_new_with_admin_role_with_attr_accessible_attributes
    p = TightPerson.new(attributes_hash, :as => :admin)

    assert_admin_attributes(p)
  end

  def test_new_with_admin_role_with_attr_protected_attributes
    p = LoosePerson.new(attributes_hash, :as => :admin)

    assert_admin_attributes(p)
  end

  def test_create_with_admin_role_with_attr_accessible_attributes
    p = TightPerson.create(attributes_hash, :as => :admin)

    assert_admin_attributes(p, true)
  end

  def test_create_with_admin_role_with_attr_protected_attributes
    p = LoosePerson.create(attributes_hash, :as => :admin)

    assert_admin_attributes(p, true)
  end

  def test_create_with_bang_with_admin_role_with_attr_accessible_attributes
    p = TightPerson.create!(attributes_hash, :as => :admin)

    assert_admin_attributes(p, true)
  end

  def test_create_with_bang_with_admin_role_with_attr_protected_attributes
    p = LoosePerson.create!(attributes_hash, :as => :admin)

    assert_admin_attributes(p, true)
  end

  def test_new_with_without_protection_with_attr_accessible_attributes
    p = TightPerson.new(attributes_hash, :without_protection => true)

    assert_all_attributes(p)
  end

  def test_new_with_without_protection_with_attr_protected_attributes
    p = LoosePerson.new(attributes_hash, :without_protection => true)

    assert_all_attributes(p)
  end

  def test_create_with_without_protection_with_attr_accessible_attributes
    p = TightPerson.create(attributes_hash, :without_protection => true)

    assert_all_attributes(p)
  end

  def test_create_with_without_protection_with_attr_protected_attributes
    p = LoosePerson.create(attributes_hash, :without_protection => true)

    assert_all_attributes(p)
  end

  def test_create_with_bang_with_without_protection_with_attr_accessible_attributes
    p = TightPerson.create!(attributes_hash, :without_protection => true)

    assert_all_attributes(p)
  end

  def test_create_with_bang_with_without_protection_with_attr_protected_attributes
    p = LoosePerson.create!(attributes_hash, :without_protection => true)

    assert_all_attributes(p)
  end

  def test_protection_against_class_attribute_writers
    [:logger, :configurations, :primary_key_prefix_type, :table_name_prefix, :table_name_suffix, :pluralize_table_names,
     :default_timezone, :schema_format, :lock_optimistically, :timestamped_migrations, :default_scopes,
     :connection_handler, :nested_attributes_options, :_attr_readonly, :attribute_types_cached_by_default,
     :attribute_method_matchers, :time_zone_aware_attributes, :skip_time_zone_conversion_for_attributes].each do |method|
      assert_respond_to  Task, method
      assert_respond_to  Task, "#{method}="
      assert_respond_to  Task.new, method
      assert !Task.new.respond_to?("#{method}=")
    end
  end

  def test_find_or_initialize_by_with_attr_accessible_attributes
    p = TightPerson.find_or_initialize_by_first_name('Josh', attributes_hash)

    assert_default_attributes(p)
  end

  def test_find_or_initialize_by_with_admin_role_with_attr_accessible_attributes
    p = TightPerson.find_or_initialize_by_first_name('Josh', attributes_hash, :as => :admin)

    assert_admin_attributes(p)
  end

  def test_find_or_initialize_by_with_attr_protected_attributes
    p = LoosePerson.find_or_initialize_by_first_name('Josh', attributes_hash)

    assert_default_attributes(p)
  end

  def test_find_or_initialize_by_with_admin_role_with_attr_protected_attributes
    p = LoosePerson.find_or_initialize_by_first_name('Josh', attributes_hash, :as => :admin)

    assert_admin_attributes(p)
  end

  def test_find_or_create_by_with_attr_accessible_attributes
    p = TightPerson.find_or_create_by_first_name('Josh', attributes_hash)

    assert_default_attributes(p, true)
  end

  def test_find_or_create_by_with_admin_role_with_attr_accessible_attributes
    p = TightPerson.find_or_create_by_first_name('Josh', attributes_hash, :as => :admin)

    assert_admin_attributes(p, true)
  end

  def test_find_or_create_by_with_attr_protected_attributes
    p = LoosePerson.find_or_create_by_first_name('Josh', attributes_hash)

    assert_default_attributes(p, true)
  end

  def test_find_or_create_by_with_admin_role_with_attr_protected_attributes
    p = LoosePerson.find_or_create_by_first_name('Josh', attributes_hash, :as => :admin)

    assert_admin_attributes(p, true)
  end

end


class MassAssignmentSecurityHasOneRelationsTest < ActiveRecord::TestCase
  include MassAssignmentTestHelpers
  include MassAssignmentRelationTestHelpers

  # build

  def test_has_one_build_with_attr_protected_attributes
    best_friend = @person.build_best_friend(attributes_hash)
    assert_default_attributes(best_friend)
  end

  def test_has_one_build_with_attr_accessible_attributes
    best_friend = @person.build_best_friend(attributes_hash)
    assert_default_attributes(best_friend)
  end

  def test_has_one_build_with_admin_role_with_attr_protected_attributes
    best_friend = @person.build_best_friend(attributes_hash, :as => :admin)
    assert_admin_attributes(best_friend)
  end

  def test_has_one_build_with_admin_role_with_attr_accessible_attributes
    best_friend = @person.build_best_friend(attributes_hash, :as => :admin)
    assert_admin_attributes(best_friend)
  end

  def test_has_one_build_without_protection
    best_friend = @person.build_best_friend(attributes_hash, :without_protection => true)
    assert_all_attributes(best_friend)
  end

  def test_has_one_build_with_strict_sanitizer
    with_strict_sanitizer do
      best_friend = @person.build_best_friend(attributes_hash.except(:id, :comments))
      assert_equal @person.id, best_friend.best_friend_id
    end
  end

  # create

  def test_has_one_create_with_attr_protected_attributes
    best_friend = @person.create_best_friend(attributes_hash)
    assert_default_attributes(best_friend, true)
  end

  def test_has_one_create_with_attr_accessible_attributes
    best_friend = @person.create_best_friend(attributes_hash)
    assert_default_attributes(best_friend, true)
  end

  def test_has_one_create_with_admin_role_with_attr_protected_attributes
    best_friend = @person.create_best_friend(attributes_hash, :as => :admin)
    assert_admin_attributes(best_friend, true)
  end

  def test_has_one_create_with_admin_role_with_attr_accessible_attributes
    best_friend = @person.create_best_friend(attributes_hash, :as => :admin)
    assert_admin_attributes(best_friend, true)
  end

  def test_has_one_create_without_protection
    best_friend = @person.create_best_friend(attributes_hash, :without_protection => true)
    assert_all_attributes(best_friend)
  end

  def test_has_one_create_with_strict_sanitizer
    with_strict_sanitizer do
      best_friend = @person.create_best_friend(attributes_hash.except(:id, :comments))
      assert_equal @person.id, best_friend.best_friend_id
    end
  end

  # create!

  def test_has_one_create_with_bang_with_attr_protected_attributes
    best_friend = @person.create_best_friend!(attributes_hash)
    assert_default_attributes(best_friend, true)
  end

  def test_has_one_create_with_bang_with_attr_accessible_attributes
    best_friend = @person.create_best_friend!(attributes_hash)
    assert_default_attributes(best_friend, true)
  end

  def test_has_one_create_with_bang_with_admin_role_with_attr_protected_attributes
    best_friend = @person.create_best_friend!(attributes_hash, :as => :admin)
    assert_admin_attributes(best_friend, true)
  end

  def test_has_one_create_with_bang_with_admin_role_with_attr_accessible_attributes
    best_friend = @person.create_best_friend!(attributes_hash, :as => :admin)
    assert_admin_attributes(best_friend, true)
  end

  def test_has_one_create_with_bang_without_protection
    best_friend = @person.create_best_friend!(attributes_hash, :without_protection => true)
    assert_all_attributes(best_friend)
  end

  def test_has_one_create_with_bang_with_strict_sanitizer
    with_strict_sanitizer do
      best_friend = @person.create_best_friend!(attributes_hash.except(:id, :comments))
      assert_equal @person.id, best_friend.best_friend_id
    end
  end

end


class MassAssignmentSecurityBelongsToRelationsTest < ActiveRecord::TestCase
  include MassAssignmentTestHelpers
  include MassAssignmentRelationTestHelpers

  # build

  def test_belongs_to_build_with_attr_protected_attributes
    best_friend = @person.build_best_friend_of(attributes_hash)
    assert_default_attributes(best_friend)
  end

  def test_belongs_to_build_with_attr_accessible_attributes
    best_friend = @person.build_best_friend_of(attributes_hash)
    assert_default_attributes(best_friend)
  end

  def test_belongs_to_build_with_admin_role_with_attr_protected_attributes
    best_friend = @person.build_best_friend_of(attributes_hash, :as => :admin)
    assert_admin_attributes(best_friend)
  end

  def test_belongs_to_build_with_admin_role_with_attr_accessible_attributes
    best_friend = @person.build_best_friend_of(attributes_hash, :as => :admin)
    assert_admin_attributes(best_friend)
  end

  def test_belongs_to_build_without_protection
    best_friend = @person.build_best_friend_of(attributes_hash, :without_protection => true)
    assert_all_attributes(best_friend)
  end

  # create

  def test_belongs_to_create_with_attr_protected_attributes
    best_friend = @person.create_best_friend_of(attributes_hash)
    assert_default_attributes(best_friend, true)
  end

  def test_belongs_to_create_with_attr_accessible_attributes
    best_friend = @person.create_best_friend_of(attributes_hash)
    assert_default_attributes(best_friend, true)
  end

  def test_belongs_to_create_with_admin_role_with_attr_protected_attributes
    best_friend = @person.create_best_friend_of(attributes_hash, :as => :admin)
    assert_admin_attributes(best_friend, true)
  end

  def test_belongs_to_create_with_admin_role_with_attr_accessible_attributes
    best_friend = @person.create_best_friend_of(attributes_hash, :as => :admin)
    assert_admin_attributes(best_friend, true)
  end

  def test_belongs_to_create_without_protection
    best_friend = @person.create_best_friend_of(attributes_hash, :without_protection => true)
    assert_all_attributes(best_friend)
  end

  def test_belongs_to_create_with_strict_sanitizer
    with_strict_sanitizer do
      best_friend = @person.create_best_friend_of(attributes_hash.except(:id, :comments))
      assert_equal best_friend.id, @person.best_friend_of_id
    end
  end

  # create!

  def test_belongs_to_create_with_bang_with_attr_protected_attributes
    best_friend = @person.create_best_friend!(attributes_hash)
    assert_default_attributes(best_friend, true)
  end

  def test_belongs_to_create_with_bang_with_attr_accessible_attributes
    best_friend = @person.create_best_friend!(attributes_hash)
    assert_default_attributes(best_friend, true)
  end

  def test_belongs_to_create_with_bang_with_admin_role_with_attr_protected_attributes
    best_friend = @person.create_best_friend!(attributes_hash, :as => :admin)
    assert_admin_attributes(best_friend, true)
  end

  def test_belongs_to_create_with_bang_with_admin_role_with_attr_accessible_attributes
    best_friend = @person.create_best_friend!(attributes_hash, :as => :admin)
    assert_admin_attributes(best_friend, true)
  end

  def test_belongs_to_create_with_bang_without_protection
    best_friend = @person.create_best_friend!(attributes_hash, :without_protection => true)
    assert_all_attributes(best_friend)
  end

  def test_belongs_to_create_with_bang_with_strict_sanitizer
    with_strict_sanitizer do
      best_friend = @person.create_best_friend_of!(attributes_hash.except(:id, :comments))
      assert_equal best_friend.id, @person.best_friend_of_id
    end
  end

end


class MassAssignmentSecurityHasManyRelationsTest < ActiveRecord::TestCase
  include MassAssignmentTestHelpers
  include MassAssignmentRelationTestHelpers

  # build

  def test_has_many_build_with_attr_protected_attributes
    best_friend = @person.best_friends.build(attributes_hash)
    assert_default_attributes(best_friend)
  end

  def test_has_many_build_with_attr_accessible_attributes
    best_friend = @person.best_friends.build(attributes_hash)
    assert_default_attributes(best_friend)
  end

  def test_has_many_build_with_admin_role_with_attr_protected_attributes
    best_friend = @person.best_friends.build(attributes_hash, :as => :admin)
    assert_admin_attributes(best_friend)
  end

  def test_has_many_build_with_admin_role_with_attr_accessible_attributes
    best_friend = @person.best_friends.build(attributes_hash, :as => :admin)
    assert_admin_attributes(best_friend)
  end

  def test_has_many_build_without_protection
    best_friend = @person.best_friends.build(attributes_hash, :without_protection => true)
    assert_all_attributes(best_friend)
  end

  def test_has_many_build_with_strict_sanitizer
    with_strict_sanitizer do
      best_friend = @person.best_friends.build(attributes_hash.except(:id, :comments))
      assert_equal @person.id, best_friend.best_friend_id
    end
  end

  # create

  def test_has_many_create_with_attr_protected_attributes
    best_friend = @person.best_friends.create(attributes_hash)
    assert_default_attributes(best_friend, true)
  end

  def test_has_many_create_with_attr_accessible_attributes
    best_friend = @person.best_friends.create(attributes_hash)
    assert_default_attributes(best_friend, true)
  end

  def test_has_many_create_with_admin_role_with_attr_protected_attributes
    best_friend = @person.best_friends.create(attributes_hash, :as => :admin)
    assert_admin_attributes(best_friend, true)
  end

  def test_has_many_create_with_admin_role_with_attr_accessible_attributes
    best_friend = @person.best_friends.create(attributes_hash, :as => :admin)
    assert_admin_attributes(best_friend, true)
  end

  def test_has_many_create_without_protection
    best_friend = @person.best_friends.create(attributes_hash, :without_protection => true)
    assert_all_attributes(best_friend)
  end

  def test_has_many_create_with_strict_sanitizer
    with_strict_sanitizer do
      best_friend = @person.best_friends.create(attributes_hash.except(:id, :comments))
      assert_equal @person.id, best_friend.best_friend_id
    end
  end

  # create!

  def test_has_many_create_with_bang_with_attr_protected_attributes
    best_friend = @person.best_friends.create!(attributes_hash)
    assert_default_attributes(best_friend, true)
  end

  def test_has_many_create_with_bang_with_attr_accessible_attributes
    best_friend = @person.best_friends.create!(attributes_hash)
    assert_default_attributes(best_friend, true)
  end

  def test_has_many_create_with_bang_with_admin_role_with_attr_protected_attributes
    best_friend = @person.best_friends.create!(attributes_hash, :as => :admin)
    assert_admin_attributes(best_friend, true)
  end

  def test_has_many_create_with_bang_with_admin_role_with_attr_accessible_attributes
    best_friend = @person.best_friends.create!(attributes_hash, :as => :admin)
    assert_admin_attributes(best_friend, true)
  end

  def test_has_many_create_with_bang_without_protection
    best_friend = @person.best_friends.create!(attributes_hash, :without_protection => true)
    assert_all_attributes(best_friend)
  end

  def test_has_many_create_with_bang_with_strict_sanitizer
    with_strict_sanitizer do
      best_friend = @person.best_friends.create!(attributes_hash.except(:id, :comments))
      assert_equal @person.id, best_friend.best_friend_id
    end
  end

end


class MassAssignmentSecurityNestedAttributesTest < ActiveRecord::TestCase
  include MassAssignmentTestHelpers

  def nested_attributes_hash(association, collection = false, except = [:id])
    if collection
      { :first_name => 'David' }.merge(:"#{association}_attributes" => [attributes_hash.except(*except)])
    else
      { :first_name => 'David' }.merge(:"#{association}_attributes" => attributes_hash.except(*except))
    end
  end

  # build

  def test_has_one_new_with_attr_protected_attributes
    person = LoosePerson.new(nested_attributes_hash(:best_friend))
    assert_default_attributes(person.best_friend)
  end

  def test_has_one_new_with_attr_accessible_attributes
    person = TightPerson.new(nested_attributes_hash(:best_friend))
    assert_default_attributes(person.best_friend)
  end

  def test_has_one_new_with_admin_role_with_attr_protected_attributes
    person = LoosePerson.new(nested_attributes_hash(:best_friend), :as => :admin)
    assert_admin_attributes(person.best_friend)
  end

  def test_has_one_new_with_admin_role_with_attr_accessible_attributes
    person = TightPerson.new(nested_attributes_hash(:best_friend), :as => :admin)
    assert_admin_attributes(person.best_friend)
  end

  def test_has_one_new_without_protection
    person = LoosePerson.new(nested_attributes_hash(:best_friend, false, nil), :without_protection => true)
    assert_all_attributes(person.best_friend)
  end

  def test_belongs_to_new_with_attr_protected_attributes
    person = LoosePerson.new(nested_attributes_hash(:best_friend_of))
    assert_default_attributes(person.best_friend_of)
  end

  def test_belongs_to_new_with_attr_accessible_attributes
    person = TightPerson.new(nested_attributes_hash(:best_friend_of))
    assert_default_attributes(person.best_friend_of)
  end

  def test_belongs_to_new_with_admin_role_with_attr_protected_attributes
    person = LoosePerson.new(nested_attributes_hash(:best_friend_of), :as => :admin)
    assert_admin_attributes(person.best_friend_of)
  end

  def test_belongs_to_new_with_admin_role_with_attr_accessible_attributes
    person = TightPerson.new(nested_attributes_hash(:best_friend_of), :as => :admin)
    assert_admin_attributes(person.best_friend_of)
  end

  def test_belongs_to_new_without_protection
    person = LoosePerson.new(nested_attributes_hash(:best_friend_of, false, nil), :without_protection => true)
    assert_all_attributes(person.best_friend_of)
  end

  def test_has_many_new_with_attr_protected_attributes
    person = LoosePerson.new(nested_attributes_hash(:best_friends, true))
    assert_default_attributes(person.best_friends.first)
  end

  def test_has_many_new_with_attr_accessible_attributes
    person = TightPerson.new(nested_attributes_hash(:best_friends, true))
    assert_default_attributes(person.best_friends.first)
  end

  def test_has_many_new_with_admin_role_with_attr_protected_attributes
    person = LoosePerson.new(nested_attributes_hash(:best_friends, true), :as => :admin)
    assert_admin_attributes(person.best_friends.first)
  end

  def test_has_many_new_with_admin_role_with_attr_accessible_attributes
    person = TightPerson.new(nested_attributes_hash(:best_friends, true), :as => :admin)
    assert_admin_attributes(person.best_friends.first)
  end

  def test_has_many_new_without_protection
    person = LoosePerson.new(nested_attributes_hash(:best_friends, true, nil), :without_protection => true)
    assert_all_attributes(person.best_friends.first)
  end

  # create

  def test_has_one_create_with_attr_protected_attributes
    person = LoosePerson.create(nested_attributes_hash(:best_friend))
    assert_default_attributes(person.best_friend, true)
  end

  def test_has_one_create_with_attr_accessible_attributes
    person = TightPerson.create(nested_attributes_hash(:best_friend))
    assert_default_attributes(person.best_friend, true)
  end

  def test_has_one_create_with_admin_role_with_attr_protected_attributes
    person = LoosePerson.create(nested_attributes_hash(:best_friend), :as => :admin)
    assert_admin_attributes(person.best_friend, true)
  end

  def test_has_one_create_with_admin_role_with_attr_accessible_attributes
    person = TightPerson.create(nested_attributes_hash(:best_friend), :as => :admin)
    assert_admin_attributes(person.best_friend, true)
  end

  def test_has_one_create_without_protection
    person = LoosePerson.create(nested_attributes_hash(:best_friend, false, nil), :without_protection => true)
    assert_all_attributes(person.best_friend)
  end

  def test_belongs_to_create_with_attr_protected_attributes
    person = LoosePerson.create(nested_attributes_hash(:best_friend_of))
    assert_default_attributes(person.best_friend_of, true)
  end

  def test_belongs_to_create_with_attr_accessible_attributes
    person = TightPerson.create(nested_attributes_hash(:best_friend_of))
    assert_default_attributes(person.best_friend_of, true)
  end

  def test_belongs_to_create_with_admin_role_with_attr_protected_attributes
    person = LoosePerson.create(nested_attributes_hash(:best_friend_of), :as => :admin)
    assert_admin_attributes(person.best_friend_of, true)
  end

  def test_belongs_to_create_with_admin_role_with_attr_accessible_attributes
    person = TightPerson.create(nested_attributes_hash(:best_friend_of), :as => :admin)
    assert_admin_attributes(person.best_friend_of, true)
  end

  def test_belongs_to_create_without_protection
    person = LoosePerson.create(nested_attributes_hash(:best_friend_of, false, nil), :without_protection => true)
    assert_all_attributes(person.best_friend_of)
  end

  def test_has_many_create_with_attr_protected_attributes
    person = LoosePerson.create(nested_attributes_hash(:best_friends, true))
    assert_default_attributes(person.best_friends.first, true)
  end

  def test_has_many_create_with_attr_accessible_attributes
    person = TightPerson.create(nested_attributes_hash(:best_friends, true))
    assert_default_attributes(person.best_friends.first, true)
  end

  def test_has_many_create_with_admin_role_with_attr_protected_attributes
    person = LoosePerson.create(nested_attributes_hash(:best_friends, true), :as => :admin)
    assert_admin_attributes(person.best_friends.first, true)
  end

  def test_has_many_create_with_admin_role_with_attr_accessible_attributes
    person = TightPerson.create(nested_attributes_hash(:best_friends, true), :as => :admin)
    assert_admin_attributes(person.best_friends.first, true)
  end

  def test_has_many_create_without_protection
    person = LoosePerson.create(nested_attributes_hash(:best_friends, true, nil), :without_protection => true)
    assert_all_attributes(person.best_friends.first)
  end

  # create!

  def test_has_one_create_with_bang_with_attr_protected_attributes
    person = LoosePerson.create!(nested_attributes_hash(:best_friend))
    assert_default_attributes(person.best_friend, true)
  end

  def test_has_one_create_with_bang_with_attr_accessible_attributes
    person = TightPerson.create!(nested_attributes_hash(:best_friend))
    assert_default_attributes(person.best_friend, true)
  end

  def test_has_one_create_with_bang_with_admin_role_with_attr_protected_attributes
    person = LoosePerson.create!(nested_attributes_hash(:best_friend), :as => :admin)
    assert_admin_attributes(person.best_friend, true)
  end

  def test_has_one_create_with_bang_with_admin_role_with_attr_accessible_attributes
    person = TightPerson.create!(nested_attributes_hash(:best_friend), :as => :admin)
    assert_admin_attributes(person.best_friend, true)
  end

  def test_has_one_create_with_bang_without_protection
    person = LoosePerson.create!(nested_attributes_hash(:best_friend, false, nil), :without_protection => true)
    assert_all_attributes(person.best_friend)
  end

  def test_belongs_to_create_with_bang_with_attr_protected_attributes
    person = LoosePerson.create!(nested_attributes_hash(:best_friend_of))
    assert_default_attributes(person.best_friend_of, true)
  end

  def test_belongs_to_create_with_bang_with_attr_accessible_attributes
    person = TightPerson.create!(nested_attributes_hash(:best_friend_of))
    assert_default_attributes(person.best_friend_of, true)
  end

  def test_belongs_to_create_with_bang_with_admin_role_with_attr_protected_attributes
    person = LoosePerson.create!(nested_attributes_hash(:best_friend_of), :as => :admin)
    assert_admin_attributes(person.best_friend_of, true)
  end

  def test_belongs_to_create_with_bang_with_admin_role_with_attr_accessible_attributes
    person = TightPerson.create!(nested_attributes_hash(:best_friend_of), :as => :admin)
    assert_admin_attributes(person.best_friend_of, true)
  end

  def test_belongs_to_create_with_bang_without_protection
    person = LoosePerson.create!(nested_attributes_hash(:best_friend_of, false, nil), :without_protection => true)
    assert_all_attributes(person.best_friend_of)
  end

  def test_has_many_create_with_bang_with_attr_protected_attributes
    person = LoosePerson.create!(nested_attributes_hash(:best_friends, true))
    assert_default_attributes(person.best_friends.first, true)
  end

  def test_has_many_create_with_bang_with_attr_accessible_attributes
    person = TightPerson.create!(nested_attributes_hash(:best_friends, true))
    assert_default_attributes(person.best_friends.first, true)
  end

  def test_has_many_create_with_bang_with_admin_role_with_attr_protected_attributes
    person = LoosePerson.create!(nested_attributes_hash(:best_friends, true), :as => :admin)
    assert_admin_attributes(person.best_friends.first, true)
  end

  def test_has_many_create_with_bang_with_admin_role_with_attr_accessible_attributes
    person = TightPerson.create!(nested_attributes_hash(:best_friends, true), :as => :admin)
    assert_admin_attributes(person.best_friends.first, true)
  end

  def test_has_many_create_with_bang_without_protection
    person = LoosePerson.create!(nested_attributes_hash(:best_friends, true, nil), :without_protection => true)
    assert_all_attributes(person.best_friends.first)
  end

end
