# frozen_string_literal: true

require "cases/helper"
require "models/man"
require "models/face"
require "models/interest"
require "models/zine"
require "models/club"
require "models/sponsor"
require "models/rating"
require "models/comment"
require "models/car"
require "models/bulb"
require "models/mixed_case_monkey"
require "models/admin"
require "models/admin/account"
require "models/admin/user"
require "models/developer"
require "models/company"
require "models/project"
require "models/author"
require "models/post"

class AutomaticInverseFindingTests < ActiveRecord::TestCase
  fixtures :ratings, :comments, :cars

  def test_has_one_and_belongs_to_should_find_inverse_automatically_on_multiple_word_name
    monkey_reflection = MixedCaseMonkey.reflect_on_association(:man)
    man_reflection = Man.reflect_on_association(:mixed_case_monkey)

    assert monkey_reflection.has_inverse?, "The monkey reflection should have an inverse"
    assert_equal man_reflection, monkey_reflection.inverse_of, "The monkey reflection's inverse should be the man reflection"

    assert man_reflection.has_inverse?, "The man reflection should have an inverse"
    assert_equal monkey_reflection, man_reflection.inverse_of, "The man reflection's inverse should be the monkey reflection"
  end

  def test_has_many_and_belongs_to_should_find_inverse_automatically_for_model_in_module
    account_reflection = Admin::Account.reflect_on_association(:users)
    user_reflection = Admin::User.reflect_on_association(:account)

    assert account_reflection.has_inverse?, "The Admin::Account reflection should have an inverse"
    assert_equal user_reflection, account_reflection.inverse_of, "The Admin::Account reflection's inverse should be the Admin::User reflection"
  end

  def test_has_one_and_belongs_to_should_find_inverse_automatically
    car_reflection = Car.reflect_on_association(:bulb)
    bulb_reflection = Bulb.reflect_on_association(:car)

    assert car_reflection.has_inverse?, "The Car reflection should have an inverse"
    assert_equal bulb_reflection, car_reflection.inverse_of, "The Car reflection's inverse should be the Bulb reflection"

    assert bulb_reflection.has_inverse?, "The Bulb reflection should have an inverse"
    assert_equal car_reflection, bulb_reflection.inverse_of, "The Bulb reflection's inverse should be the Car reflection"
  end

  def test_has_many_and_belongs_to_should_find_inverse_automatically
    comment_reflection = Comment.reflect_on_association(:ratings)
    rating_reflection = Rating.reflect_on_association(:comment)

    assert comment_reflection.has_inverse?, "The Comment reflection should have an inverse"
    assert_equal rating_reflection, comment_reflection.inverse_of, "The Comment reflection's inverse should be the Rating reflection"
  end

  def test_has_many_and_belongs_to_should_find_inverse_automatically_for_sti
    author_reflection = Author.reflect_on_association(:posts)
    author_child_reflection = Author.reflect_on_association(:special_posts)
    post_reflection = Post.reflect_on_association(:author)

    assert_respond_to author_reflection, :has_inverse?
    assert author_reflection.has_inverse?, "The Author reflection should have an inverse"
    assert_equal post_reflection, author_reflection.inverse_of, "The Author reflection's inverse should be the Post reflection"

    assert_respond_to author_child_reflection, :has_inverse?
    assert author_child_reflection.has_inverse?, "The Author reflection should have an inverse"
    assert_equal post_reflection, author_child_reflection.inverse_of, "The Author reflection's inverse should be the Post reflection"
  end

  def test_has_one_and_belongs_to_automatic_inverse_shares_objects
    car = Car.first
    bulb = Bulb.create!(car: car)

    assert_equal car.bulb, bulb, "The Car's bulb should be the original bulb"

    car.bulb.color = "Blue"
    assert_equal car.bulb.color, bulb.color, "Changing the bulb's color on the car association should change the bulb's color"

    bulb.color = "Red"
    assert_equal bulb.color, car.bulb.color, "Changing the bulb's color should change the bulb's color on the car association"
  end

  def test_has_many_and_belongs_to_automatic_inverse_shares_objects_on_rating
    comment = Comment.first
    rating = Rating.create!(comment: comment)

    assert_equal rating.comment, comment, "The Rating's comment should be the original Comment"

    rating.comment.body = "Fennec foxes are the smallest of the foxes."
    assert_equal rating.comment.body, comment.body, "Changing the Comment's body on the association should change the original Comment's body"

    comment.body = "Kittens are adorable."
    assert_equal comment.body, rating.comment.body, "Changing the original Comment's body should change the Comment's body on the association"
  end

  def test_has_many_and_belongs_to_automatic_inverse_shares_objects_on_comment
    rating = Rating.create!
    comment = Comment.first
    rating.comment = comment

    assert_equal rating.comment, comment, "The Rating's comment should be the original Comment"

    rating.comment.body = "Fennec foxes are the smallest of the foxes."
    assert_equal rating.comment.body, comment.body, "Changing the Comment's body on the association should change the original Comment's body"

    comment.body = "Kittens are adorable."
    assert_equal comment.body, rating.comment.body, "Changing the original Comment's body should change the Comment's body on the association"
  end

  def test_polymorphic_and_has_many_through_relationships_should_not_have_inverses
    sponsor_reflection = Sponsor.reflect_on_association(:sponsorable)

    assert !sponsor_reflection.has_inverse?, "A polymorphic association should not find an inverse automatically"

    club_reflection = Club.reflect_on_association(:members)

    assert !club_reflection.has_inverse?, "A has_many_through association should not find an inverse automatically"
  end

  def test_polymorphic_has_one_should_find_inverse_automatically
    man_reflection = Man.reflect_on_association(:polymorphic_face_without_inverse)

    assert man_reflection.has_inverse?
  end
end

class InverseAssociationTests < ActiveRecord::TestCase
  def test_should_allow_for_inverse_of_options_in_associations
    assert_nothing_raised do
      Class.new(ActiveRecord::Base).has_many(:wheels, inverse_of: :car)
    end

    assert_nothing_raised do
      Class.new(ActiveRecord::Base).has_one(:engine, inverse_of: :car)
    end

    assert_nothing_raised do
      Class.new(ActiveRecord::Base).belongs_to(:car, inverse_of: :driver)
    end
  end

  def test_should_be_able_to_ask_a_reflection_if_it_has_an_inverse
    has_one_with_inverse_ref = Man.reflect_on_association(:face)
    assert has_one_with_inverse_ref.has_inverse?

    has_many_with_inverse_ref = Man.reflect_on_association(:interests)
    assert has_many_with_inverse_ref.has_inverse?

    belongs_to_with_inverse_ref = Face.reflect_on_association(:man)
    assert belongs_to_with_inverse_ref.has_inverse?

    has_one_without_inverse_ref = Club.reflect_on_association(:sponsor)
    assert !has_one_without_inverse_ref.has_inverse?

    has_many_without_inverse_ref = Club.reflect_on_association(:memberships)
    assert !has_many_without_inverse_ref.has_inverse?

    belongs_to_without_inverse_ref = Sponsor.reflect_on_association(:sponsor_club)
    assert !belongs_to_without_inverse_ref.has_inverse?
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

  def test_this_inverse_stuff
    firm = Firm.create!(name: "Adequate Holdings")
    Project.create!(name: "Project 1", firm: firm)
    Developer.create!(name: "Gorbypuff", firm: firm)

    new_project = Project.last
    assert Project.reflect_on_association(:lead_developer).inverse_of.present?, "Expected inverse of to be present"
    assert new_project.lead_developer.present?, "Expected lead developer to be present on the project"
  end
end

class InverseHasOneTests < ActiveRecord::TestCase
  fixtures :men, :faces

  def test_parent_instance_should_be_shared_with_child_on_find
    m = men(:gordon)
    f = m.face
    assert_equal m.name, f.man.name, "Name of man should be the same before changes to parent instance"
    m.name = "Bongo"
    assert_equal m.name, f.man.name, "Name of man should be the same after changes to parent instance"
    f.man.name = "Mungo"
    assert_equal m.name, f.man.name, "Name of man should be the same after changes to child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_eager_loaded_child_on_find
    m = Man.all.merge!(where: { name: "Gordon" }, includes: :face).first
    f = m.face
    assert_equal m.name, f.man.name, "Name of man should be the same before changes to parent instance"
    m.name = "Bongo"
    assert_equal m.name, f.man.name, "Name of man should be the same after changes to parent instance"
    f.man.name = "Mungo"
    assert_equal m.name, f.man.name, "Name of man should be the same after changes to child-owned instance"

    m = Man.all.merge!(where: { name: "Gordon" }, includes: :face, order: "faces.id").first
    f = m.face
    assert_equal m.name, f.man.name, "Name of man should be the same before changes to parent instance"
    m.name = "Bongo"
    assert_equal m.name, f.man.name, "Name of man should be the same after changes to parent instance"
    f.man.name = "Mungo"
    assert_equal m.name, f.man.name, "Name of man should be the same after changes to child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_newly_built_child
    m = Man.first
    f = m.build_face(description: "haunted")
    assert_not_nil f.man
    assert_equal m.name, f.man.name, "Name of man should be the same before changes to parent instance"
    m.name = "Bongo"
    assert_equal m.name, f.man.name, "Name of man should be the same after changes to parent instance"
    f.man.name = "Mungo"
    assert_equal m.name, f.man.name, "Name of man should be the same after changes to just-built-child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_newly_created_child
    m = Man.first
    f = m.create_face(description: "haunted")
    assert_not_nil f.man
    assert_equal m.name, f.man.name, "Name of man should be the same before changes to parent instance"
    m.name = "Bongo"
    assert_equal m.name, f.man.name, "Name of man should be the same after changes to parent instance"
    f.man.name = "Mungo"
    assert_equal m.name, f.man.name, "Name of man should be the same after changes to newly-created-child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_newly_created_child_via_bang_method
    m = Man.first
    f = m.create_face!(description: "haunted")
    assert_not_nil f.man
    assert_equal m.name, f.man.name, "Name of man should be the same before changes to parent instance"
    m.name = "Bongo"
    assert_equal m.name, f.man.name, "Name of man should be the same after changes to parent instance"
    f.man.name = "Mungo"
    assert_equal m.name, f.man.name, "Name of man should be the same after changes to newly-created-child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_replaced_via_accessor_child
    m = Man.first
    f = Face.new(description: "haunted")
    m.face = f
    assert_not_nil f.man
    assert_equal m.name, f.man.name, "Name of man should be the same before changes to parent instance"
    m.name = "Bongo"
    assert_equal m.name, f.man.name, "Name of man should be the same after changes to parent instance"
    f.man.name = "Mungo"
    assert_equal m.name, f.man.name, "Name of man should be the same after changes to replaced-child-owned instance"
  end

  def test_trying_to_use_inverses_that_dont_exist_should_raise_an_error
    assert_raise(ActiveRecord::InverseOfAssociationNotFoundError) { Man.first.dirty_face }
  end
end

class InverseHasManyTests < ActiveRecord::TestCase
  fixtures :men, :interests, :posts, :authors, :author_addresses

  def test_parent_instance_should_be_shared_with_every_child_on_find
    m = men(:gordon)
    is = m.interests
    is.each do |i|
      assert_equal m.name, i.man.name, "Name of man should be the same before changes to parent instance"
      m.name = "Bongo"
      assert_equal m.name, i.man.name, "Name of man should be the same after changes to parent instance"
      i.man.name = "Mungo"
      assert_equal m.name, i.man.name, "Name of man should be the same after changes to child-owned instance"
    end
  end

  def test_parent_instance_should_be_shared_with_every_child_on_find_for_sti
    a = authors(:david)
    ps = a.posts
    ps.each do |p|
      assert_equal a.name, p.author.name, "Name of man should be the same before changes to parent instance"
      a.name = "Bongo"
      assert_equal a.name, p.author.name, "Name of man should be the same after changes to parent instance"
      p.author.name = "Mungo"
      assert_equal a.name, p.author.name, "Name of man should be the same after changes to child-owned instance"
    end

    sps = a.special_posts
    sps.each do |sp|
      assert_equal a.name, sp.author.name, "Name of man should be the same before changes to parent instance"
      a.name = "Bongo"
      assert_equal a.name, sp.author.name, "Name of man should be the same after changes to parent instance"
      sp.author.name = "Mungo"
      assert_equal a.name, sp.author.name, "Name of man should be the same after changes to child-owned instance"
    end
  end

  def test_parent_instance_should_be_shared_with_eager_loaded_children
    m = Man.all.merge!(where: { name: "Gordon" }, includes: :interests).first
    is = m.interests
    is.each do |i|
      assert_equal m.name, i.man.name, "Name of man should be the same before changes to parent instance"
      m.name = "Bongo"
      assert_equal m.name, i.man.name, "Name of man should be the same after changes to parent instance"
      i.man.name = "Mungo"
      assert_equal m.name, i.man.name, "Name of man should be the same after changes to child-owned instance"
    end

    m = Man.all.merge!(where: { name: "Gordon" }, includes: :interests, order: "interests.id").first
    is = m.interests
    is.each do |i|
      assert_equal m.name, i.man.name, "Name of man should be the same before changes to parent instance"
      m.name = "Bongo"
      assert_equal m.name, i.man.name, "Name of man should be the same after changes to parent instance"
      i.man.name = "Mungo"
      assert_equal m.name, i.man.name, "Name of man should be the same after changes to child-owned instance"
    end
  end

  def test_parent_instance_should_be_shared_with_newly_block_style_built_child
    m = Man.first
    i = m.interests.build { |ii| ii.topic = "Industrial Revolution Re-enactment" }
    assert_not_nil i.topic, "Child attributes supplied to build via blocks should be populated"
    assert_not_nil i.man
    assert_equal m.name, i.man.name, "Name of man should be the same before changes to parent instance"
    m.name = "Bongo"
    assert_equal m.name, i.man.name, "Name of man should be the same after changes to parent instance"
    i.man.name = "Mungo"
    assert_equal m.name, i.man.name, "Name of man should be the same after changes to just-built-child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_newly_created_via_bang_method_child
    m = Man.first
    i = m.interests.create!(topic: "Industrial Revolution Re-enactment")
    assert_not_nil i.man
    assert_equal m.name, i.man.name, "Name of man should be the same before changes to parent instance"
    m.name = "Bongo"
    assert_equal m.name, i.man.name, "Name of man should be the same after changes to parent instance"
    i.man.name = "Mungo"
    assert_equal m.name, i.man.name, "Name of man should be the same after changes to newly-created-child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_newly_block_style_created_child
    m = Man.first
    i = m.interests.create { |ii| ii.topic = "Industrial Revolution Re-enactment" }
    assert_not_nil i.topic, "Child attributes supplied to create via blocks should be populated"
    assert_not_nil i.man
    assert_equal m.name, i.man.name, "Name of man should be the same before changes to parent instance"
    m.name = "Bongo"
    assert_equal m.name, i.man.name, "Name of man should be the same after changes to parent instance"
    i.man.name = "Mungo"
    assert_equal m.name, i.man.name, "Name of man should be the same after changes to newly-created-child-owned instance"
  end

  def test_parent_instance_should_be_shared_within_create_block_of_new_child
    man = Man.first
    interest = man.interests.create do |i|
      assert i.man.equal?(man), "Man of child should be the same instance as a parent"
    end
    assert interest.man.equal?(man), "Man of the child should still be the same instance as a parent"
  end

  def test_parent_instance_should_be_shared_within_build_block_of_new_child
    man = Man.first
    interest = man.interests.build do |i|
      assert i.man.equal?(man), "Man of child should be the same instance as a parent"
    end
    assert interest.man.equal?(man), "Man of the child should still be the same instance as a parent"
  end

  def test_parent_instance_should_be_shared_with_poked_in_child
    m = men(:gordon)
    i = Interest.create(topic: "Industrial Revolution Re-enactment")
    m.interests << i
    assert_not_nil i.man
    assert_equal m.name, i.man.name, "Name of man should be the same before changes to parent instance"
    m.name = "Bongo"
    assert_equal m.name, i.man.name, "Name of man should be the same after changes to parent instance"
    i.man.name = "Mungo"
    assert_equal m.name, i.man.name, "Name of man should be the same after changes to newly-created-child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_replaced_via_accessor_children
    m = Man.first
    i = Interest.new(topic: "Industrial Revolution Re-enactment")
    m.interests = [i]
    assert_not_nil i.man
    assert_equal m.name, i.man.name, "Name of man should be the same before changes to parent instance"
    m.name = "Bongo"
    assert_equal m.name, i.man.name, "Name of man should be the same after changes to parent instance"
    i.man.name = "Mungo"
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

  def test_parent_instance_should_find_child_instance_using_child_instance_id
    man = Man.create!
    interest = Interest.create!
    man.interests = [interest]

    assert interest.equal?(man.interests.first), "The inverse association should use the interest already created and held in memory"
    assert interest.equal?(man.interests.find(interest.id)), "The inverse association should use the interest already created and held in memory"
    assert man.equal?(man.interests.first.man), "Two inversion should lead back to the same object that was originally held"
    assert man.equal?(man.interests.find(interest.id).man), "Two inversions should lead back to the same object that was originally held"
  end

  def test_parent_instance_should_find_child_instance_using_child_instance_id_when_created
    man = Man.create!
    interest = Interest.create!(man: man)

    assert man.equal?(man.interests.first.man), "Two inverses should lead back to the same object that was originally held"
    assert man.equal?(man.interests.find(interest.id).man), "Two inversions should lead back to the same object that was originally held"

    assert_nil man.interests.find(interest.id).man.name, "The name of the man should match before the name is changed"
    man.name = "Ben Bitdiddle"
    assert_equal man.name, man.interests.find(interest.id).man.name, "The name of the man should match after the parent name is changed"
    man.interests.find(interest.id).man.name = "Alyssa P. Hacker"
    assert_equal man.name, man.interests.find(interest.id).man.name, "The name of the man should match after the child name is changed"
  end

  def test_find_on_child_instance_with_id_should_not_load_all_child_records
    man = Man.create!
    interest = Interest.create!(man: man)

    man.interests.find(interest.id)
    assert_not man.interests.loaded?
  end

  def test_raise_record_not_found_error_when_invalid_ids_are_passed
    # delete all interest records to ensure that hard coded invalid_id(s)
    # are indeed invalid.
    Interest.delete_all

    man = Man.create!

    invalid_id = 245324523
    assert_raise(ActiveRecord::RecordNotFound) { man.interests.find(invalid_id) }

    invalid_ids = [8432342, 2390102913, 2453245234523452]
    assert_raise(ActiveRecord::RecordNotFound) { man.interests.find(invalid_ids) }
  end

  def test_raise_record_not_found_error_when_no_ids_are_passed
    man = Man.create!

    exception = assert_raise(ActiveRecord::RecordNotFound) { man.interests.load.find() }

    assert_equal exception.model, "Interest"
    assert_equal exception.primary_key, "id"
  end

  def test_trying_to_use_inverses_that_dont_exist_should_raise_an_error
    assert_raise(ActiveRecord::InverseOfAssociationNotFoundError) { Man.first.secret_interests }
  end

  def test_child_instance_should_point_to_parent_without_saving
    man = Man.new
    i = Interest.create(topic: "Industrial Revolution Re-enactment")

    man.interests << i
    assert_not_nil i.man

    i.man.name = "Charles"
    assert_equal i.man.name, man.name

    assert !man.persisted?
  end

  def test_inverse_instance_should_be_set_before_find_callbacks_are_run
    reset_callbacks(Interest, :find) do
      Interest.after_find { raise unless association(:man).loaded? && man.present? }

      assert Man.first.interests.reload.any?
      assert Man.includes(:interests).first.interests.any?
      assert Man.joins(:interests).includes(:interests).first.interests.any?
    end
  end

  def test_inverse_instance_should_be_set_before_initialize_callbacks_are_run
    reset_callbacks(Interest, :initialize) do
      Interest.after_initialize { raise unless association(:man).loaded? && man.present? }

      assert Man.first.interests.reload.any?
      assert Man.includes(:interests).first.interests.any?
      assert Man.joins(:interests).includes(:interests).first.interests.any?
    end
  end

  def reset_callbacks(target, type)
    old_callbacks = target.send(:get_callbacks, type).deep_dup
    yield
  ensure
    target.send(:set_callbacks, type, old_callbacks) if old_callbacks
  end
end

class InverseBelongsToTests < ActiveRecord::TestCase
  fixtures :men, :faces, :interests

  def test_child_instance_should_be_shared_with_parent_on_find
    f = faces(:trusting)
    m = f.man
    assert_equal f.description, m.face.description, "Description of face should be the same before changes to child instance"
    f.description = "gormless"
    assert_equal f.description, m.face.description, "Description of face should be the same after changes to child instance"
    m.face.description = "pleasing"
    assert_equal f.description, m.face.description, "Description of face should be the same after changes to parent-owned instance"
  end

  def test_eager_loaded_child_instance_should_be_shared_with_parent_on_find
    f = Face.all.merge!(includes: :man, where: { description: "trusting" }).first
    m = f.man
    assert_equal f.description, m.face.description, "Description of face should be the same before changes to child instance"
    f.description = "gormless"
    assert_equal f.description, m.face.description, "Description of face should be the same after changes to child instance"
    m.face.description = "pleasing"
    assert_equal f.description, m.face.description, "Description of face should be the same after changes to parent-owned instance"

    f = Face.all.merge!(includes: :man, order: "men.id", where: { description: "trusting" }).first
    m = f.man
    assert_equal f.description, m.face.description, "Description of face should be the same before changes to child instance"
    f.description = "gormless"
    assert_equal f.description, m.face.description, "Description of face should be the same after changes to child instance"
    m.face.description = "pleasing"
    assert_equal f.description, m.face.description, "Description of face should be the same after changes to parent-owned instance"
  end

  def test_child_instance_should_be_shared_with_newly_built_parent
    f = faces(:trusting)
    m = f.build_man(name: "Charles")
    assert_not_nil m.face
    assert_equal f.description, m.face.description, "Description of face should be the same before changes to child instance"
    f.description = "gormless"
    assert_equal f.description, m.face.description, "Description of face should be the same after changes to child instance"
    m.face.description = "pleasing"
    assert_equal f.description, m.face.description, "Description of face should be the same after changes to just-built-parent-owned instance"
  end

  def test_child_instance_should_be_shared_with_newly_created_parent
    f = faces(:trusting)
    m = f.create_man(name: "Charles")
    assert_not_nil m.face
    assert_equal f.description, m.face.description, "Description of face should be the same before changes to child instance"
    f.description = "gormless"
    assert_equal f.description, m.face.description, "Description of face should be the same after changes to child instance"
    m.face.description = "pleasing"
    assert_equal f.description, m.face.description, "Description of face should be the same after changes to newly-created-parent-owned instance"
  end

  def test_should_not_try_to_set_inverse_instances_when_the_inverse_is_a_has_many
    i = interests(:trainspotting)
    m = i.man
    assert_not_nil m.interests
    iz = m.interests.detect { |_iz| _iz.id == i.id }
    assert_not_nil iz
    assert_equal i.topic, iz.topic, "Interest topics should be the same before changes to child"
    i.topic = "Eating cheese with a spoon"
    assert_not_equal i.topic, iz.topic, "Interest topics should not be the same after changes to child"
    iz.topic = "Cow tipping"
    assert_not_equal i.topic, iz.topic, "Interest topics should not be the same after changes to parent-owned instance"
  end

  def test_child_instance_should_be_shared_with_replaced_via_accessor_parent
    f = Face.first
    m = Man.new(name: "Charles")
    f.man = m
    assert_not_nil m.face
    assert_equal f.description, m.face.description, "Description of face should be the same before changes to child instance"
    f.description = "gormless"
    assert_equal f.description, m.face.description, "Description of face should be the same after changes to child instance"
    m.face.description = "pleasing"
    assert_equal f.description, m.face.description, "Description of face should be the same after changes to replaced-parent-owned instance"
  end

  def test_trying_to_use_inverses_that_dont_exist_should_raise_an_error
    assert_raise(ActiveRecord::InverseOfAssociationNotFoundError) { Face.first.horrible_man }
  end
end

class InversePolymorphicBelongsToTests < ActiveRecord::TestCase
  fixtures :men, :faces, :interests

  def test_child_instance_should_be_shared_with_parent_on_find
    f = Face.all.merge!(where: { description: "confused" }).first
    m = f.polymorphic_man
    assert_equal f.description, m.polymorphic_face.description, "Description of face should be the same before changes to child instance"
    f.description = "gormless"
    assert_equal f.description, m.polymorphic_face.description, "Description of face should be the same after changes to child instance"
    m.polymorphic_face.description = "pleasing"
    assert_equal f.description, m.polymorphic_face.description, "Description of face should be the same after changes to parent-owned instance"
  end

  def test_eager_loaded_child_instance_should_be_shared_with_parent_on_find
    f = Face.all.merge!(where: { description: "confused" }, includes: :man).first
    m = f.polymorphic_man
    assert_equal f.description, m.polymorphic_face.description, "Description of face should be the same before changes to child instance"
    f.description = "gormless"
    assert_equal f.description, m.polymorphic_face.description, "Description of face should be the same after changes to child instance"
    m.polymorphic_face.description = "pleasing"
    assert_equal f.description, m.polymorphic_face.description, "Description of face should be the same after changes to parent-owned instance"

    f = Face.all.merge!(where: { description: "confused" }, includes: :man, order: "men.id").first
    m = f.polymorphic_man
    assert_equal f.description, m.polymorphic_face.description, "Description of face should be the same before changes to child instance"
    f.description = "gormless"
    assert_equal f.description, m.polymorphic_face.description, "Description of face should be the same after changes to child instance"
    m.polymorphic_face.description = "pleasing"
    assert_equal f.description, m.polymorphic_face.description, "Description of face should be the same after changes to parent-owned instance"
  end

  def test_child_instance_should_be_shared_with_replaced_via_accessor_parent
    face = faces(:confused)
    new_man = Man.new

    assert_not_nil face.polymorphic_man
    face.polymorphic_man = new_man

    assert_equal face.description, new_man.polymorphic_face.description, "Description of face should be the same before changes to parent instance"
    face.description = "Bongo"
    assert_equal face.description, new_man.polymorphic_face.description, "Description of face should be the same after changes to parent instance"
    new_man.polymorphic_face.description = "Mungo"
    assert_equal face.description, new_man.polymorphic_face.description, "Description of face should be the same after changes to replaced-parent-owned instance"
  end

  def test_inversed_instance_should_not_be_reloaded_after_stale_state_changed
    new_man = Man.new
    face = Face.new
    new_man.face = face

    old_inversed_man = face.man
    new_man.save!
    new_inversed_man = face.man

    assert_equal old_inversed_man.object_id, new_inversed_man.object_id
  end

  def test_inversed_instance_should_not_be_reloaded_after_stale_state_changed_with_validation
    face = Face.new man: Man.new

    old_inversed_man = face.man
    face.save!
    new_inversed_man = face.man

    assert_equal old_inversed_man.object_id, new_inversed_man.object_id
  end

  def test_should_not_try_to_set_inverse_instances_when_the_inverse_is_a_has_many
    i = interests(:llama_wrangling)
    m = i.polymorphic_man
    assert_not_nil m.polymorphic_interests
    iz = m.polymorphic_interests.detect { |_iz| _iz.id == i.id }
    assert_not_nil iz
    assert_equal i.topic, iz.topic, "Interest topics should be the same before changes to child"
    i.topic = "Eating cheese with a spoon"
    assert_not_equal i.topic, iz.topic, "Interest topics should not be the same after changes to child"
    iz.topic = "Cow tipping"
    assert_not_equal i.topic, iz.topic, "Interest topics should not be the same after changes to parent-owned instance"
  end

  def test_trying_to_access_inverses_that_dont_exist_shouldnt_raise_an_error
    # Ideally this would, if only for symmetry's sake with other association types
    assert_nothing_raised { Face.first.horrible_polymorphic_man }
  end

  def test_trying_to_set_polymorphic_inverses_that_dont_exist_at_all_should_raise_an_error
    # fails because no class has the correct inverse_of for horrible_polymorphic_man
    assert_raise(ActiveRecord::InverseOfAssociationNotFoundError) { Face.first.horrible_polymorphic_man = Man.first }
  end

  def test_trying_to_set_polymorphic_inverses_that_dont_exist_on_the_instance_being_set_should_raise_an_error
    # passes because Man does have the correct inverse_of
    assert_nothing_raised { Face.first.polymorphic_man = Man.first }
    # fails because Interest does have the correct inverse_of
    assert_raise(ActiveRecord::InverseOfAssociationNotFoundError) { Face.first.polymorphic_man = Interest.first }
  end
end

# NOTE - these tests might not be meaningful, ripped as they were from the parental_control plugin
# which would guess the inverse rather than look for an explicit configuration option.
class InverseMultipleHasManyInversesForSameModel < ActiveRecord::TestCase
  fixtures :men, :interests, :zines

  def test_that_we_can_load_associations_that_have_the_same_reciprocal_name_from_different_models
    assert_nothing_raised do
      i = Interest.first
      i.zine
      i.man
    end
  end

  def test_that_we_can_create_associations_that_have_the_same_reciprocal_name_from_different_models
    assert_nothing_raised do
      i = Interest.first
      i.build_zine(title: "Get Some in Winter! 2008")
      i.build_man(name: "Gordon")
      i.save!
    end
  end
end
