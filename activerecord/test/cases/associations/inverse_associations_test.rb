require "cases/helper"
require 'models/man'
require 'models/face'
require 'models/interest'
require 'models/zine'
require 'models/club'
require 'models/sponsor'

class InverseAssociationTests < ActiveRecord::TestCase
  def test_should_allow_for_inverse_of_options_in_associations
    assert_nothing_raised(ArgumentError, 'ActiveRecord should allow the inverse_of options on has_many') do
      Class.new(ActiveRecord::Base).has_many(:wheels, :inverse_of => :car)
    end

    assert_nothing_raised(ArgumentError, 'ActiveRecord should allow the inverse_of options on has_one') do
      Class.new(ActiveRecord::Base).has_one(:engine, :inverse_of => :car)
    end

    assert_nothing_raised(ArgumentError, 'ActiveRecord should allow the inverse_of options on belongs_to') do
      Class.new(ActiveRecord::Base).belongs_to(:car, :inverse_of => :driver)
    end
  end

  def test_should_be_able_to_ask_a_reflection_if_it_has_an_inverse
    has_one_with_inverse_ref = Man.reflect_on_association(:face)
    assert_respond_to has_one_with_inverse_ref, :has_inverse?
    assert has_one_with_inverse_ref.has_inverse?

    has_many_with_inverse_ref = Man.reflect_on_association(:interests)
    assert_respond_to has_many_with_inverse_ref, :has_inverse?
    assert has_many_with_inverse_ref.has_inverse?

    belongs_to_with_inverse_ref = Face.reflect_on_association(:man)
    assert_respond_to belongs_to_with_inverse_ref, :has_inverse?
    assert belongs_to_with_inverse_ref.has_inverse?

    has_one_without_inverse_ref = Club.reflect_on_association(:sponsor)
    assert_respond_to has_one_without_inverse_ref, :has_inverse?
    assert !has_one_without_inverse_ref.has_inverse?

    has_many_without_inverse_ref = Club.reflect_on_association(:memberships)
    assert_respond_to has_many_without_inverse_ref, :has_inverse?
    assert !has_many_without_inverse_ref.has_inverse?

    belongs_to_without_inverse_ref = Sponsor.reflect_on_association(:sponsor_club)
    assert_respond_to belongs_to_without_inverse_ref, :has_inverse?
    assert !belongs_to_without_inverse_ref.has_inverse?
  end

  def test_should_be_able_to_ask_a_reflection_what_it_is_the_inverse_of
    has_one_ref = Man.reflect_on_association(:face)
    assert_respond_to has_one_ref, :inverse_of

    has_many_ref = Man.reflect_on_association(:interests)
    assert_respond_to has_many_ref, :inverse_of

    belongs_to_ref = Face.reflect_on_association(:man)
    assert_respond_to belongs_to_ref, :inverse_of
  end

  def test_inverse_of_method_should_supply_the_actual_reflection_instance_it_is_the_inverse_of
    has_one_ref = Man.reflect_on_association(:face)
    assert_equal Face.reflect_on_association(:man), has_one_ref.inverse_of

    has_many_ref = Man.reflect_on_association(:interests)
    assert_equal Interest.reflect_on_association(:man), has_many_ref.inverse_of

    belongs_to_ref = Face.reflect_on_association(:man)
    assert_equal Man.reflect_on_association(:face), belongs_to_ref.inverse_of
  end

  def test_associations_with_no_inverse_of_should_return_nil
    has_one_ref = Club.reflect_on_association(:sponsor)
    assert_nil has_one_ref.inverse_of

    has_many_ref = Club.reflect_on_association(:memberships)
    assert_nil has_many_ref.inverse_of

    belongs_to_ref = Sponsor.reflect_on_association(:sponsor_club)
    assert_nil belongs_to_ref.inverse_of
  end
end

class InverseHasOneTests < ActiveRecord::TestCase
  fixtures :men, :faces

  def test_parent_instance_should_be_shared_with_child_on_find
    m = men(:gordon)
    f = m.face
    assert_equal m.name, f.man.name, "Name of man should be the same before changes to parent instance"
    m.name = 'Bongo'
    assert_equal m.name, f.man.name, "Name of man should be the same after changes to parent instance"
    f.man.name = 'Mungo'
    assert_equal m.name, f.man.name, "Name of man should be the same after changes to child-owned instance"
  end


  def test_parent_instance_should_be_shared_with_eager_loaded_child_on_find
    m = Man.all.merge!(:where => {:name => 'Gordon'}, :includes => :face).first
    f = m.face
    assert_equal m.name, f.man.name, "Name of man should be the same before changes to parent instance"
    m.name = 'Bongo'
    assert_equal m.name, f.man.name, "Name of man should be the same after changes to parent instance"
    f.man.name = 'Mungo'
    assert_equal m.name, f.man.name, "Name of man should be the same after changes to child-owned instance"

    m = Man.all.merge!(:where => {:name => 'Gordon'}, :includes => :face, :order => 'faces.id').first
    f = m.face
    assert_equal m.name, f.man.name, "Name of man should be the same before changes to parent instance"
    m.name = 'Bongo'
    assert_equal m.name, f.man.name, "Name of man should be the same after changes to parent instance"
    f.man.name = 'Mungo'
    assert_equal m.name, f.man.name, "Name of man should be the same after changes to child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_newly_built_child
    m = Man.first
    f = m.build_face(:description => 'haunted')
    assert_not_nil f.man
    assert_equal m.name, f.man.name, "Name of man should be the same before changes to parent instance"
    m.name = 'Bongo'
    assert_equal m.name, f.man.name, "Name of man should be the same after changes to parent instance"
    f.man.name = 'Mungo'
    assert_equal m.name, f.man.name, "Name of man should be the same after changes to just-built-child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_newly_created_child
    m = Man.first
    f = m.create_face(:description => 'haunted')
    assert_not_nil f.man
    assert_equal m.name, f.man.name, "Name of man should be the same before changes to parent instance"
    m.name = 'Bongo'
    assert_equal m.name, f.man.name, "Name of man should be the same after changes to parent instance"
    f.man.name = 'Mungo'
    assert_equal m.name, f.man.name, "Name of man should be the same after changes to newly-created-child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_newly_created_child_via_bang_method
    m = Man.first
    f = m.create_face!(:description => 'haunted')
    assert_not_nil f.man
    assert_equal m.name, f.man.name, "Name of man should be the same before changes to parent instance"
    m.name = 'Bongo'
    assert_equal m.name, f.man.name, "Name of man should be the same after changes to parent instance"
    f.man.name = 'Mungo'
    assert_equal m.name, f.man.name, "Name of man should be the same after changes to newly-created-child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_replaced_via_accessor_child
    m = Man.first
    f = Face.new(:description => 'haunted')
    m.face = f
    assert_not_nil f.man
    assert_equal m.name, f.man.name, "Name of man should be the same before changes to parent instance"
    m.name = 'Bongo'
    assert_equal m.name, f.man.name, "Name of man should be the same after changes to parent instance"
    f.man.name = 'Mungo'
    assert_equal m.name, f.man.name, "Name of man should be the same after changes to replaced-child-owned instance"
  end

  def test_trying_to_use_inverses_that_dont_exist_should_raise_an_error
    assert_raise(ActiveRecord::InverseOfAssociationNotFoundError) { Man.first.dirty_face }
  end
end

class InverseHasManyTests < ActiveRecord::TestCase
  fixtures :men, :interests

  def test_parent_instance_should_be_shared_with_every_child_on_find
    m = men(:gordon)
    is = m.interests
    is.each do |i|
      assert_equal m.name, i.man.name, "Name of man should be the same before changes to parent instance"
      m.name = 'Bongo'
      assert_equal m.name, i.man.name, "Name of man should be the same after changes to parent instance"
      i.man.name = 'Mungo'
      assert_equal m.name, i.man.name, "Name of man should be the same after changes to child-owned instance"
    end
  end

  def test_parent_instance_should_be_shared_with_eager_loaded_children
    m = Man.all.merge!(:where => {:name => 'Gordon'}, :includes => :interests).first
    is = m.interests
    is.each do |i|
      assert_equal m.name, i.man.name, "Name of man should be the same before changes to parent instance"
      m.name = 'Bongo'
      assert_equal m.name, i.man.name, "Name of man should be the same after changes to parent instance"
      i.man.name = 'Mungo'
      assert_equal m.name, i.man.name, "Name of man should be the same after changes to child-owned instance"
    end

    m = Man.all.merge!(:where => {:name => 'Gordon'}, :includes => :interests, :order => 'interests.id').first
    is = m.interests
    is.each do |i|
      assert_equal m.name, i.man.name, "Name of man should be the same before changes to parent instance"
      m.name = 'Bongo'
      assert_equal m.name, i.man.name, "Name of man should be the same after changes to parent instance"
      i.man.name = 'Mungo'
      assert_equal m.name, i.man.name, "Name of man should be the same after changes to child-owned instance"
    end
  end

  def test_parent_instance_should_be_shared_with_newly_block_style_built_child
    m = Man.first
    i = m.interests.build {|ii| ii.topic = 'Industrial Revolution Re-enactment'}
    assert_not_nil i.topic, "Child attributes supplied to build via blocks should be populated"
    assert_not_nil i.man
    assert_equal m.name, i.man.name, "Name of man should be the same before changes to parent instance"
    m.name = 'Bongo'
    assert_equal m.name, i.man.name, "Name of man should be the same after changes to parent instance"
    i.man.name = 'Mungo'
    assert_equal m.name, i.man.name, "Name of man should be the same after changes to just-built-child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_newly_created_via_bang_method_child
    m = Man.first
    i = m.interests.create!(:topic => 'Industrial Revolution Re-enactment')
    assert_not_nil i.man
    assert_equal m.name, i.man.name, "Name of man should be the same before changes to parent instance"
    m.name = 'Bongo'
    assert_equal m.name, i.man.name, "Name of man should be the same after changes to parent instance"
    i.man.name = 'Mungo'
    assert_equal m.name, i.man.name, "Name of man should be the same after changes to newly-created-child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_newly_block_style_created_child
    m = Man.first
    i = m.interests.create {|ii| ii.topic = 'Industrial Revolution Re-enactment'}
    assert_not_nil i.topic, "Child attributes supplied to create via blocks should be populated"
    assert_not_nil i.man
    assert_equal m.name, i.man.name, "Name of man should be the same before changes to parent instance"
    m.name = 'Bongo'
    assert_equal m.name, i.man.name, "Name of man should be the same after changes to parent instance"
    i.man.name = 'Mungo'
    assert_equal m.name, i.man.name, "Name of man should be the same after changes to newly-created-child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_poked_in_child
    m = men(:gordon)
    i = Interest.create(:topic => 'Industrial Revolution Re-enactment')
    m.interests << i
    assert_not_nil i.man
    assert_equal m.name, i.man.name, "Name of man should be the same before changes to parent instance"
    m.name = 'Bongo'
    assert_equal m.name, i.man.name, "Name of man should be the same after changes to parent instance"
    i.man.name = 'Mungo'
    assert_equal m.name, i.man.name, "Name of man should be the same after changes to newly-created-child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_replaced_via_accessor_children
    m = Man.first
    i = Interest.new(:topic => 'Industrial Revolution Re-enactment')
    m.interests = [i]
    assert_not_nil i.man
    assert_equal m.name, i.man.name, "Name of man should be the same before changes to parent instance"
    m.name = 'Bongo'
    assert_equal m.name, i.man.name, "Name of man should be the same after changes to parent instance"
    i.man.name = 'Mungo'
    assert_equal m.name, i.man.name, "Name of man should be the same after changes to replaced-child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_first_and_last_child
    man = Man.first

    assert man.interests.first.man.equal? man
    assert man.interests.last.man.equal? man
  end

  def test_parent_instance_should_be_shared_with_first_n_and_last_n_children
    man = Man.first

    interests = man.interests.first(2)
    assert interests[0].man.equal? man
    assert interests[1].man.equal? man

    interests = man.interests.last(2)
    assert interests[0].man.equal? man
    assert interests[1].man.equal? man
  end

  def test_trying_to_use_inverses_that_dont_exist_should_raise_an_error
    assert_raise(ActiveRecord::InverseOfAssociationNotFoundError) { Man.first.secret_interests }
  end
end

class InverseBelongsToTests < ActiveRecord::TestCase
  fixtures :men, :faces, :interests

  def test_child_instance_should_be_shared_with_parent_on_find
    f = faces(:trusting)
    m = f.man
    assert_equal f.description, m.face.description, "Description of face should be the same before changes to child instance"
    f.description = 'gormless'
    assert_equal f.description, m.face.description, "Description of face should be the same after changes to child instance"
    m.face.description = 'pleasing'
    assert_equal f.description, m.face.description, "Description of face should be the same after changes to parent-owned instance"
  end

  def test_eager_loaded_child_instance_should_be_shared_with_parent_on_find
    f = Face.all.merge!(:includes => :man, :where => {:description => 'trusting'}).first
    m = f.man
    assert_equal f.description, m.face.description, "Description of face should be the same before changes to child instance"
    f.description = 'gormless'
    assert_equal f.description, m.face.description, "Description of face should be the same after changes to child instance"
    m.face.description = 'pleasing'
    assert_equal f.description, m.face.description, "Description of face should be the same after changes to parent-owned instance"

    f = Face.all.merge!(:includes => :man, :order => 'men.id', :where => {:description => 'trusting'}).first
    m = f.man
    assert_equal f.description, m.face.description, "Description of face should be the same before changes to child instance"
    f.description = 'gormless'
    assert_equal f.description, m.face.description, "Description of face should be the same after changes to child instance"
    m.face.description = 'pleasing'
    assert_equal f.description, m.face.description, "Description of face should be the same after changes to parent-owned instance"
  end

  def test_child_instance_should_be_shared_with_newly_built_parent
    f = faces(:trusting)
    m = f.build_man(:name => 'Charles')
    assert_not_nil m.face
    assert_equal f.description, m.face.description, "Description of face should be the same before changes to child instance"
    f.description = 'gormless'
    assert_equal f.description, m.face.description, "Description of face should be the same after changes to child instance"
    m.face.description = 'pleasing'
    assert_equal f.description, m.face.description, "Description of face should be the same after changes to just-built-parent-owned instance"
  end

  def test_child_instance_should_be_shared_with_newly_created_parent
    f = faces(:trusting)
    m = f.create_man(:name => 'Charles')
    assert_not_nil m.face
    assert_equal f.description, m.face.description, "Description of face should be the same before changes to child instance"
    f.description = 'gormless'
    assert_equal f.description, m.face.description, "Description of face should be the same after changes to child instance"
    m.face.description = 'pleasing'
    assert_equal f.description, m.face.description, "Description of face should be the same after changes to newly-created-parent-owned instance"
  end

  def test_should_not_try_to_set_inverse_instances_when_the_inverse_is_a_has_many
    i = interests(:trainspotting)
    m = i.man
    assert_not_nil m.interests
    iz = m.interests.detect { |_iz| _iz.id == i.id}
    assert_not_nil iz
    assert_equal i.topic, iz.topic, "Interest topics should be the same before changes to child"
    i.topic = 'Eating cheese with a spoon'
    assert_not_equal i.topic, iz.topic, "Interest topics should not be the same after changes to child"
    iz.topic = 'Cow tipping'
    assert_not_equal i.topic, iz.topic, "Interest topics should not be the same after changes to parent-owned instance"
  end

  def test_child_instance_should_be_shared_with_replaced_via_accessor_parent
    f = Face.first
    m = Man.new(:name => 'Charles')
    f.man = m
    assert_not_nil m.face
    assert_equal f.description, m.face.description, "Description of face should be the same before changes to child instance"
    f.description = 'gormless'
    assert_equal f.description, m.face.description, "Description of face should be the same after changes to child instance"
    m.face.description = 'pleasing'
    assert_equal f.description, m.face.description, "Description of face should be the same after changes to replaced-parent-owned instance"
  end

  def test_trying_to_use_inverses_that_dont_exist_should_raise_an_error
    assert_raise(ActiveRecord::InverseOfAssociationNotFoundError) { Face.first.horrible_man }
  end
end

class InversePolymorphicBelongsToTests < ActiveRecord::TestCase
  fixtures :men, :faces, :interests

  def test_child_instance_should_be_shared_with_parent_on_find
    f = Face.all.merge!(:where => {:description => 'confused'}).first
    m = f.polymorphic_man
    assert_equal f.description, m.polymorphic_face.description, "Description of face should be the same before changes to child instance"
    f.description = 'gormless'
    assert_equal f.description, m.polymorphic_face.description, "Description of face should be the same after changes to child instance"
    m.polymorphic_face.description = 'pleasing'
    assert_equal f.description, m.polymorphic_face.description, "Description of face should be the same after changes to parent-owned instance"
  end

  def test_eager_loaded_child_instance_should_be_shared_with_parent_on_find
    f = Face.all.merge!(:where => {:description => 'confused'}, :includes => :man).first
    m = f.polymorphic_man
    assert_equal f.description, m.polymorphic_face.description, "Description of face should be the same before changes to child instance"
    f.description = 'gormless'
    assert_equal f.description, m.polymorphic_face.description, "Description of face should be the same after changes to child instance"
    m.polymorphic_face.description = 'pleasing'
    assert_equal f.description, m.polymorphic_face.description, "Description of face should be the same after changes to parent-owned instance"

    f = Face.all.merge!(:where => {:description => 'confused'}, :includes => :man, :order => 'men.id').first
    m = f.polymorphic_man
    assert_equal f.description, m.polymorphic_face.description, "Description of face should be the same before changes to child instance"
    f.description = 'gormless'
    assert_equal f.description, m.polymorphic_face.description, "Description of face should be the same after changes to child instance"
    m.polymorphic_face.description = 'pleasing'
    assert_equal f.description, m.polymorphic_face.description, "Description of face should be the same after changes to parent-owned instance"
  end

  def test_child_instance_should_be_shared_with_replaced_via_accessor_parent
    face = faces(:confused)
    new_man = Man.new

    assert_not_nil face.polymorphic_man
    face.polymorphic_man = new_man

    assert_equal face.description, new_man.polymorphic_face.description, "Description of face should be the same before changes to parent instance"
    face.description = 'Bongo'
    assert_equal face.description, new_man.polymorphic_face.description, "Description of face should be the same after changes to parent instance"
    new_man.polymorphic_face.description = 'Mungo'
    assert_equal face.description, new_man.polymorphic_face.description, "Description of face should be the same after changes to replaced-parent-owned instance"
  end

  def test_child_instance_should_be_shared_with_replaced_via_method_parent
    face = faces(:confused)
    new_man = Man.new

    assert_not_nil face.polymorphic_man
    face.polymorphic_man = new_man

    assert_equal face.description, new_man.polymorphic_face.description, "Description of face should be the same before changes to parent instance"
    face.description = 'Bongo'
    assert_equal face.description, new_man.polymorphic_face.description, "Description of face should be the same after changes to parent instance"
    new_man.polymorphic_face.description = 'Mungo'
    assert_equal face.description, new_man.polymorphic_face.description, "Description of face should be the same after changes to replaced-parent-owned instance"
  end

  def test_should_not_try_to_set_inverse_instances_when_the_inverse_is_a_has_many
    i = interests(:llama_wrangling)
    m = i.polymorphic_man
    assert_not_nil m.polymorphic_interests
    iz = m.polymorphic_interests.detect { |_iz| _iz.id == i.id}
    assert_not_nil iz
    assert_equal i.topic, iz.topic, "Interest topics should be the same before changes to child"
    i.topic = 'Eating cheese with a spoon'
    assert_not_equal i.topic, iz.topic, "Interest topics should not be the same after changes to child"
    iz.topic = 'Cow tipping'
    assert_not_equal i.topic, iz.topic, "Interest topics should not be the same after changes to parent-owned instance"
  end

  def test_trying_to_access_inverses_that_dont_exist_shouldnt_raise_an_error
    # Ideally this would, if only for symmetry's sake with other association types
    assert_nothing_raised(ActiveRecord::InverseOfAssociationNotFoundError) { Face.first.horrible_polymorphic_man }
  end

  def test_trying_to_set_polymorphic_inverses_that_dont_exist_at_all_should_raise_an_error
    # fails because no class has the correct inverse_of for horrible_polymorphic_man
    assert_raise(ActiveRecord::InverseOfAssociationNotFoundError) { Face.first.horrible_polymorphic_man = Man.first }
  end

  def test_trying_to_set_polymorphic_inverses_that_dont_exist_on_the_instance_being_set_should_raise_an_error
    # passes because Man does have the correct inverse_of
    assert_nothing_raised(ActiveRecord::InverseOfAssociationNotFoundError) { Face.first.polymorphic_man = Man.first }
    # fails because Interest does have the correct inverse_of
    assert_raise(ActiveRecord::InverseOfAssociationNotFoundError) { Face.first.polymorphic_man = Interest.first }
  end
end

# NOTE - these tests might not be meaningful, ripped as they were from the parental_control plugin
# which would guess the inverse rather than look for an explicit configuration option.
class InverseMultipleHasManyInversesForSameModel < ActiveRecord::TestCase
  fixtures :men, :interests, :zines

  def test_that_we_can_load_associations_that_have_the_same_reciprocal_name_from_different_models
    assert_nothing_raised(ActiveRecord::AssociationTypeMismatch) do
      i = Interest.first
      i.zine
      i.man
    end
  end

  def test_that_we_can_create_associations_that_have_the_same_reciprocal_name_from_different_models
    assert_nothing_raised(ActiveRecord::AssociationTypeMismatch) do
      i = Interest.first
      i.build_zine(:title => 'Get Some in Winter! 2008')
      i.build_man(:name => 'Gordon')
      i.save!
    end
  end
end
