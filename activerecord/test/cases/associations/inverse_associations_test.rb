# frozen_string_literal: true

require "cases/helper"
require "models/human"
require "models/face"
require "models/interest"
require "models/zine"
require "models/club"
require "models/sponsor"
require "models/rating"
require "models/post"
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
require "models/user"
require "models/room"
require "models/contract"
require "models/subscription"
require "models/book"
require "models/branch"

class AutomaticInverseFindingTests < ActiveRecord::TestCase
  fixtures :ratings, :comments, :cars, :books

  def test_has_one_and_belongs_to_should_find_inverse_automatically_on_multiple_word_name
    monkey_reflection = MixedCaseMonkey.reflect_on_association(:human)
    human_reflection = Human.reflect_on_association(:mixed_case_monkey)

    assert monkey_reflection.has_inverse?, "The monkey reflection should have an inverse"
    assert_equal human_reflection, monkey_reflection.inverse_of, "The monkey reflection's inverse should be the human reflection"

    assert human_reflection.has_inverse?, "The human reflection should have an inverse"
    assert_equal monkey_reflection, human_reflection.inverse_of, "The human reflection's inverse should be the monkey reflection"
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

  def test_has_many_and_belongs_to_should_find_inverse_automatically_for_extension_block
    comment_reflection = Comment.reflect_on_association(:post)
    post_reflection = Post.reflect_on_association(:comments)

    assert_predicate post_reflection, :has_inverse?
    assert_equal comment_reflection, post_reflection.inverse_of
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

  def test_has_one_and_belongs_to_with_non_default_foreign_key_should_not_find_inverse_automatically
    user = User.create!
    owned_room = Room.create!(owner: user)

    assert_nil user.room
    assert_nil owned_room.user

    assert_equal user, owned_room.owner
    assert_equal owned_room, user.owned_room
  end

  def test_has_one_and_belongs_to_with_custom_association_name_should_not_find_wrong_inverse_automatically
    user_reflection = Room.reflect_on_association(:user)
    owner_reflection = Room.reflect_on_association(:owner)
    room_reflection = User.reflect_on_association(:room)

    assert_predicate user_reflection, :has_inverse?
    assert_equal room_reflection, user_reflection.inverse_of

    assert_not_predicate owner_reflection, :has_inverse?
    assert_not_equal room_reflection, owner_reflection.inverse_of
  end

  def test_has_many_and_belongs_to_with_a_scope_and_automatic_scope_inversing_should_find_inverse_automatically
    contacts_reflection = Company.reflect_on_association(:special_contracts)
    company_reflection = SpecialContract.reflect_on_association(:company)

    assert contacts_reflection.scope
    assert_not company_reflection.scope

    with_automatic_scope_inversing(contacts_reflection, company_reflection) do
      assert_predicate contacts_reflection, :has_inverse?
      assert_equal company_reflection, contacts_reflection.inverse_of
      assert_not_equal contacts_reflection, company_reflection.inverse_of
    end
  end

  def test_has_one_and_belongs_to_with_a_scope_and_automatic_scope_inversing_should_find_inverse_automatically
    post_reflection = Author.reflect_on_association(:recent_post)
    author_reflection = Post.reflect_on_association(:author)

    assert post_reflection.scope
    assert_not author_reflection.scope

    with_automatic_scope_inversing(post_reflection, author_reflection) do
      assert_predicate post_reflection, :has_inverse?
      assert_equal author_reflection, post_reflection.inverse_of
      assert_not_equal post_reflection, author_reflection.inverse_of
    end
  end

  def test_has_many_with_scoped_belongs_to_does_not_find_inverse_automatically
    book = books(:tlg)
    book.update_attribute(:author_visibility, :invisible)

    assert_nil book.subscriptions.new.book

    subscription_reflection = Book.reflect_on_association(:subscriptions)
    book_reflection = Subscription.reflect_on_association(:book)

    assert_not subscription_reflection.scope
    assert book_reflection.scope

    with_automatic_scope_inversing(book_reflection, subscription_reflection) do
      assert_nil book.subscriptions.new.book
    end
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

    assert_not sponsor_reflection.has_inverse?, "A polymorphic association should not find an inverse automatically"

    club_reflection = Club.reflect_on_association(:members)

    assert_not club_reflection.has_inverse?, "A has_many_through association should not find an inverse automatically"
  end

  def test_polymorphic_has_one_should_find_inverse_automatically
    human_reflection = Human.reflect_on_association(:polymorphic_face_without_inverse)

    assert_predicate human_reflection, :has_inverse?
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
    has_one_with_inverse_ref = Human.reflect_on_association(:face)
    assert_predicate has_one_with_inverse_ref, :has_inverse?

    has_many_with_inverse_ref = Human.reflect_on_association(:interests)
    assert_predicate has_many_with_inverse_ref, :has_inverse?

    belongs_to_with_inverse_ref = Face.reflect_on_association(:human)
    assert_predicate belongs_to_with_inverse_ref, :has_inverse?

    has_one_without_inverse_ref = Club.reflect_on_association(:sponsor)
    assert_not_predicate has_one_without_inverse_ref, :has_inverse?

    has_many_without_inverse_ref = Club.reflect_on_association(:memberships)
    assert_not_predicate has_many_without_inverse_ref, :has_inverse?

    belongs_to_without_inverse_ref = Sponsor.reflect_on_association(:sponsor_club)
    assert_not_predicate belongs_to_without_inverse_ref, :has_inverse?
  end

  def test_inverse_of_method_should_supply_the_actual_reflection_instance_it_is_the_inverse_of
    has_one_ref = Human.reflect_on_association(:face)
    assert_equal Face.reflect_on_association(:human), has_one_ref.inverse_of

    has_many_ref = Human.reflect_on_association(:interests)
    assert_equal Interest.reflect_on_association(:human), has_many_ref.inverse_of

    belongs_to_ref = Face.reflect_on_association(:human)
    assert_equal Human.reflect_on_association(:face), belongs_to_ref.inverse_of
  end

  def test_associations_with_no_inverse_of_should_return_nil
    has_one_ref = Club.reflect_on_association(:sponsor)
    assert_nil has_one_ref.inverse_of

    has_many_ref = Club.reflect_on_association(:memberships)
    assert_nil has_many_ref.inverse_of

    belongs_to_ref = Sponsor.reflect_on_association(:sponsor_club)
    assert_nil belongs_to_ref.inverse_of
  end

  def test_polymorphic_associations_dont_attempt_to_find_inverse_of
    belongs_to_ref = Sponsor.reflect_on_association(:sponsor)
    assert_raise(ArgumentError) { belongs_to_ref.klass }
    assert_nil belongs_to_ref.inverse_of

    belongs_to_ref = Face.reflect_on_association(:super_human)
    assert_raise(ArgumentError) { belongs_to_ref.klass }
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
  fixtures :humans, :faces

  def test_parent_instance_should_be_shared_with_child_on_find
    human = humans(:gordon)
    face = human.face
    assert_equal human.name, face.human.name, "Name of human should be the same before changes to parent instance"
    human.name = "Bongo"
    assert_equal human.name, face.human.name, "Name of human should be the same after changes to parent instance"
    face.human.name = "Mungo"
    assert_equal human.name, face.human.name, "Name of human should be the same after changes to child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_eager_loaded_child_on_find
    human = Human.all.merge!(where: { name: "Gordon" }, includes: :face).first
    face = human.face
    assert_equal human.name, face.human.name, "Name of human should be the same before changes to parent instance"
    human.name = "Bongo"
    assert_equal human.name, face.human.name, "Name of human should be the same after changes to parent instance"
    face.human.name = "Mungo"
    assert_equal human.name, face.human.name, "Name of human should be the same after changes to child-owned instance"

    human = Human.all.merge!(where: { name: "Gordon" }, includes: :face, order: "faces.id").first
    face = human.face
    assert_equal human.name, face.human.name, "Name of human should be the same before changes to parent instance"
    human.name = "Bongo"
    assert_equal human.name, face.human.name, "Name of human should be the same after changes to parent instance"
    face.human.name = "Mungo"
    assert_equal human.name, face.human.name, "Name of human should be the same after changes to child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_newly_built_child
    human = Human.first
    face = human.build_face(description: "haunted")
    assert_not_nil face.human
    assert_equal human.name, face.human.name, "Name of human should be the same before changes to parent instance"
    human.name = "Bongo"
    assert_equal human.name, face.human.name, "Name of human should be the same after changes to parent instance"
    face.human.name = "Mungo"
    assert_equal human.name, face.human.name, "Name of human should be the same after changes to just-built-child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_newly_created_child
    human = Human.first
    face = human.create_face(description: "haunted")
    assert_not_nil face.human
    assert_equal human.name, face.human.name, "Name of human should be the same before changes to parent instance"
    human.name = "Bongo"
    assert_equal human.name, face.human.name, "Name of human should be the same after changes to parent instance"
    face.human.name = "Mungo"
    assert_equal human.name, face.human.name, "Name of human should be the same after changes to newly-created-child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_newly_created_child_via_bang_method
    human = Human.first
    face = human.create_face!(description: "haunted")
    assert_not_nil face.human
    assert_equal human.name, face.human.name, "Name of human should be the same before changes to parent instance"
    human.name = "Bongo"
    assert_equal human.name, face.human.name, "Name of human should be the same after changes to parent instance"
    face.human.name = "Mungo"
    assert_equal human.name, face.human.name, "Name of human should be the same after changes to newly-created-child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_replaced_via_accessor_child
    human = Human.first
    face = Face.new(description: "haunted")
    human.face = face
    assert_not_nil face.human
    assert_equal human.name, face.human.name, "Name of human should be the same before changes to parent instance"
    human.name = "Bongo"
    assert_equal human.name, face.human.name, "Name of human should be the same after changes to parent instance"
    face.human.name = "Mungo"
    assert_equal human.name, face.human.name, "Name of human should be the same after changes to replaced-child-owned instance"
  end

  def test_child_instance_should_be_shared_with_replaced_via_accessor_parent
    human = Human.first
    face = Face.create!(description: "haunted", human: Human.last)
    face.human = human
    assert_equal face, human.face
    assert_equal face.description, human.face.description, "Description of the face should be the same before changes to child instance"
    face.description = "Bongo"
    assert_equal face.description, human.face.description, "Description of the face should be the same after changes to child instance"
    human.face.description = "Mungo"
    assert_equal face.description, human.face.description, "Description of the face should be the same after changes to replaced-parent-owned instance"
  end

  def test_trying_to_use_inverses_that_dont_exist_should_raise_an_error
    assert_raise(ActiveRecord::InverseOfAssociationNotFoundError) { Human.first.confused_face }
  end

  def test_trying_to_use_inverses_that_dont_exist_should_have_suggestions_for_fix
    error = assert_raise(ActiveRecord::InverseOfAssociationNotFoundError) {
      Human.first.confused_face
    }

    assert_match "Did you mean?", error.message
    assert_equal "confused_human", error.corrections.first
  end
end

class InverseHasManyTests < ActiveRecord::TestCase
  fixtures :humans, :interests, :posts, :authors, :author_addresses, :comments

  def test_parent_instance_should_be_shared_with_every_child_on_find
    human = humans(:gordon)
    interests = human.interests
    interests.each do |interest|
      assert_equal human.name, interest.human.name, "Name of human should be the same before changes to parent instance"
      human.name = "Bongo"
      assert_equal human.name, interest.human.name, "Name of human should be the same after changes to parent instance"
      interest.human.name = "Mungo"
      assert_equal human.name, interest.human.name, "Name of human should be the same after changes to child-owned instance"
    end
  end

  def test_parent_instance_should_be_shared_with_every_child_on_find_for_sti
    author = authors(:david)
    posts = author.posts
    posts.each do |post|
      assert_equal author.name, post.author.name, "Name of human should be the same before changes to parent instance"
      author.name = "Bongo"
      assert_equal author.name, post.author.name, "Name of human should be the same after changes to parent instance"
      post.author.name = "Mungo"
      assert_equal author.name, post.author.name, "Name of human should be the same after changes to child-owned instance"
    end

    special_posts = author.special_posts
    special_posts.each do |post|
      assert_equal author.name, post.author.name, "Name of human should be the same before changes to parent instance"
      author.name = "Bongo"
      assert_equal author.name, post.author.name, "Name of human should be the same after changes to parent instance"
      post.author.name = "Mungo"
      assert_equal author.name, post.author.name, "Name of human should be the same after changes to child-owned instance"
    end
  end

  def test_parent_instance_should_be_shared_with_eager_loaded_children
    human = Human.all.merge!(where: { name: "Gordon" }, includes: :interests).first
    interests = human.interests
    interests.each do |interest|
      assert_equal human.name, interest.human.name, "Name of human should be the same before changes to parent instance"
      human.name = "Bongo"
      assert_equal human.name, interest.human.name, "Name of human should be the same after changes to parent instance"
      interest.human.name = "Mungo"
      assert_equal human.name, interest.human.name, "Name of human should be the same after changes to child-owned instance"
    end

    human = Human.all.merge!(where: { name: "Gordon" }, includes: :interests, order: "interests.id").first
    interests = human.interests
    interests.each do |interest|
      assert_equal human.name, interest.human.name, "Name of human should be the same before changes to parent instance"
      human.name = "Bongo"
      assert_equal human.name, interest.human.name, "Name of human should be the same after changes to parent instance"
      interest.human.name = "Mungo"
      assert_equal human.name, interest.human.name, "Name of human should be the same after changes to child-owned instance"
    end
  end

  def test_parent_instance_should_be_shared_with_newly_block_style_built_child
    human = Human.first
    interest = human.interests.build { |ii| ii.topic = "Industrial Revolution Re-enactment" }
    assert_not_nil interest.topic, "Child attributes supplied to build via blocks should be populated"
    assert_not_nil interest.human
    assert_equal human.name, interest.human.name, "Name of human should be the same before changes to parent instance"
    human.name = "Bongo"
    assert_equal human.name, interest.human.name, "Name of human should be the same after changes to parent instance"
    interest.human.name = "Mungo"
    assert_equal human.name, interest.human.name, "Name of human should be the same after changes to just-built-child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_newly_created_via_bang_method_child
    human = Human.first
    interest = human.interests.create!(topic: "Industrial Revolution Re-enactment")
    assert_not_nil interest.human
    assert_equal human.name, interest.human.name, "Name of human should be the same before changes to parent instance"
    human.name = "Bongo"
    assert_equal human.name, interest.human.name, "Name of human should be the same after changes to parent instance"
    interest.human.name = "Mungo"
    assert_equal human.name, interest.human.name, "Name of human should be the same after changes to newly-created-child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_newly_block_style_created_child
    human = Human.first
    interest = human.interests.create { |ii| ii.topic = "Industrial Revolution Re-enactment" }
    assert_not_nil interest.topic, "Child attributes supplied to create via blocks should be populated"
    assert_not_nil interest.human
    assert_equal human.name, interest.human.name, "Name of human should be the same before changes to parent instance"
    human.name = "Bongo"
    assert_equal human.name, interest.human.name, "Name of human should be the same after changes to parent instance"
    interest.human.name = "Mungo"
    assert_equal human.name, interest.human.name, "Name of human should be the same after changes to newly-created-child-owned instance"
  end

  def test_parent_instance_should_be_shared_within_create_block_of_new_child
    human = Human.first
    interest = human.interests.create do |i|
      assert i.human.equal?(human), "Human of child should be the same instance as a parent"
    end
    assert interest.human.equal?(human), "Human of the child should still be the same instance as a parent"
  end

  def test_parent_instance_should_be_shared_within_build_block_of_new_child
    human = Human.first
    interest = human.interests.build do |i|
      assert i.human.equal?(human), "Human of child should be the same instance as a parent"
    end
    assert interest.human.equal?(human), "Human of the child should still be the same instance as a parent"
  end

  def test_parent_instance_should_be_shared_with_poked_in_child
    human = humans(:gordon)
    interest = Interest.create(topic: "Industrial Revolution Re-enactment")
    human.interests << interest
    assert_not_nil interest.human
    assert_equal human.name, interest.human.name, "Name of human should be the same before changes to parent instance"
    human.name = "Bongo"
    assert_equal human.name, interest.human.name, "Name of human should be the same after changes to parent instance"
    interest.human.name = "Mungo"
    assert_equal human.name, interest.human.name, "Name of human should be the same after changes to newly-created-child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_replaced_via_accessor_children
    human = Human.first
    interest = Interest.new(topic: "Industrial Revolution Re-enactment")
    human.interests = [interest]
    assert_not_nil interest.human
    assert_equal human.name, interest.human.name, "Name of human should be the same before changes to parent instance"
    human.name = "Bongo"
    assert_equal human.name, interest.human.name, "Name of human should be the same after changes to parent instance"
    interest.human.name = "Mungo"
    assert_equal human.name, interest.human.name, "Name of human should be the same after changes to replaced-child-owned instance"
  end

  def test_parent_instance_should_be_shared_with_first_and_last_child
    human = Human.first

    assert human.interests.first.human.equal? human
    assert human.interests.last.human.equal? human
  end

  def test_parent_instance_should_be_shared_with_first_n_and_last_n_children
    human = Human.first

    interests = human.interests.first(2)
    assert interests[0].human.equal? human
    assert interests[1].human.equal? human

    interests = human.interests.last(2)
    assert interests[0].human.equal? human
    assert interests[1].human.equal? human
  end

  def test_parent_instance_should_find_child_instance_using_child_instance_id
    human = Human.create!
    interest = Interest.create!
    human.interests = [interest]

    assert interest.equal?(human.interests.first), "The inverse association should use the interest already created and held in memory"
    assert interest.equal?(human.interests.find(interest.id)), "The inverse association should use the interest already created and held in memory"
    assert human.equal?(human.interests.first.human), "Two inversion should lead back to the same object that was originally held"
    assert human.equal?(human.interests.find(interest.id).human), "Two inversions should lead back to the same object that was originally held"
  end

  def test_parent_instance_should_find_child_instance_using_child_instance_id_when_created
    human = Human.create!
    interest = Interest.create!(human: human)

    assert human.equal?(human.interests.first.human), "Two inverses should lead back to the same object that was originally held"
    assert human.equal?(human.interests.find(interest.id).human), "Two inversions should lead back to the same object that was originally held"

    assert_nil human.interests.find(interest.id).human.name, "The name of the human should match before the name is changed"
    human.name = "Ben Bitdiddle"
    assert_equal human.name, human.interests.find(interest.id).human.name, "The name of the human should match after the parent name is changed"
    human.interests.find(interest.id).human.name = "Alyssa P. Hacker"
    assert_equal human.name, human.interests.find(interest.id).human.name, "The name of the human should match after the child name is changed"
  end

  def test_find_on_child_instance_with_id_should_not_load_all_child_records
    human = Human.create!
    interest = Interest.create!(human: human)

    human.interests.find(interest.id)
    assert_not_predicate human.interests, :loaded?
  end

  def test_find_on_child_instance_with_id_should_set_inverse_instances
    human = Human.create!
    interest = Interest.create!(human: human)

    child = human.interests.find(interest.id)
    assert_predicate child.association(:human), :loaded?
  end

  def test_find_on_child_instances_with_ids_should_set_inverse_instances
    human = Human.create!
    interests = Array.new(2) { Interest.create!(human: human) }

    children = human.interests.find(interests.pluck(:id))
    children.each do |child|
      assert_predicate child.association(:human), :loaded?
    end
  end

  def test_raise_record_not_found_error_when_invalid_ids_are_passed
    # delete all interest records to ensure that hard coded invalid_id(s)
    # are indeed invalid.
    Interest.delete_all

    human = Human.create!

    invalid_id = 245324523
    assert_raise(ActiveRecord::RecordNotFound) { human.interests.find(invalid_id) }

    invalid_ids = [8432342, 2390102913, 2453245234523452]
    assert_raise(ActiveRecord::RecordNotFound) { human.interests.find(invalid_ids) }
  end

  def test_raise_record_not_found_error_when_no_ids_are_passed
    human = Human.create!

    exception = assert_raise(ActiveRecord::RecordNotFound) { human.interests.load.find() }

    assert_equal exception.model, "Interest"
    assert_equal exception.primary_key, "id"
  end

  def test_trying_to_use_inverses_that_dont_exist_should_raise_an_error
    assert_raise(ActiveRecord::InverseOfAssociationNotFoundError) { Human.first.secret_interests }
  end

  def test_child_instance_should_point_to_parent_without_saving
    human = Human.new
    interest = Interest.create(topic: "Industrial Revolution Re-enactment")

    human.interests << interest
    assert_not_nil interest.human

    interest.human.name = "Charles"
    assert_equal interest.human.name, human.name

    assert_not_predicate human, :persisted?
  end

  def test_inverse_instance_should_be_set_before_find_callbacks_are_run
    reset_callbacks(Interest, :find) do
      Interest.after_find { raise unless association(:human).loaded? && human.present? }

      assert_predicate Human.first.interests.reload, :any?
      assert_predicate Human.includes(:interests).first.interests, :any?
      assert_predicate Human.joins(:interests).includes(:interests).first.interests, :any?
    end
  end

  def test_inverse_instance_should_be_set_before_initialize_callbacks_are_run
    reset_callbacks(Interest, :initialize) do
      Interest.after_initialize { raise unless association(:human).loaded? && human.present? }

      assert_predicate Human.first.interests.reload, :any?
      assert_predicate Human.includes(:interests).first.interests, :any?
      assert_predicate Human.joins(:interests).includes(:interests).first.interests, :any?
    end
  end

  def test_inverse_works_when_the_association_self_references_the_same_object
    comment = comments(:greetings)
    Comment.create!(parent: comment, post_id: comment.post_id, body: "New Comment")

    comment.body = "OMG"
    assert_equal comment.body, comment.children.first.parent.body
  end

  def test_changing_the_association_id_makes_the_inversed_association_target_stale
    post1 = Post.first
    post2 = Post.second
    comment = post1.comments.first

    assert_same post1, comment.post

    comment.update!(post_id: post2.id)

    assert_equal post2, comment.post
  end
end

class InverseBelongsToTests < ActiveRecord::TestCase
  fixtures :humans, :faces, :interests

  def test_child_instance_should_be_shared_with_parent_on_find
    face = faces(:trusting)
    human = face.human
    assert_equal face.description, human.face.description, "Description of face should be the same before changes to child instance"
    face.description = "gormless"
    assert_equal face.description, human.face.description, "Description of face should be the same after changes to child instance"
    human.face.description = "pleasing"
    assert_equal face.description, human.face.description, "Description of face should be the same after changes to parent-owned instance"
  end

  def test_eager_loaded_child_instance_should_be_shared_with_parent_on_find
    face = Face.all.merge!(includes: :human, where: { description: "trusting" }).first
    human = face.human
    assert_equal face.description, human.face.description, "Description of face should be the same before changes to child instance"
    face.description = "gormless"
    assert_equal face.description, human.face.description, "Description of face should be the same after changes to child instance"
    human.face.description = "pleasing"
    assert_equal face.description, human.face.description, "Description of face should be the same after changes to parent-owned instance"

    face = Face.all.merge!(includes: :human, order: "humans.id", where: { description: "trusting" }).first
    human = face.human
    assert_equal face.description, human.face.description, "Description of face should be the same before changes to child instance"
    face.description = "gormless"
    assert_equal face.description, human.face.description, "Description of face should be the same after changes to child instance"
    human.face.description = "pleasing"
    assert_equal face.description, human.face.description, "Description of face should be the same after changes to parent-owned instance"
  end

  def test_child_instance_should_be_shared_with_newly_built_parent
    face = faces(:trusting)
    human = face.build_human(name: "Charles")
    assert_not_nil human.face
    assert_equal face.description, human.face.description, "Description of face should be the same before changes to child instance"
    face.description = "gormless"
    assert_equal face.description, human.face.description, "Description of face should be the same after changes to child instance"
    human.face.description = "pleasing"
    assert_equal face.description, human.face.description, "Description of face should be the same after changes to just-built-parent-owned instance"
  end

  def test_child_instance_should_be_shared_with_newly_created_parent
    face = faces(:trusting)
    human = face.create_human(name: "Charles")
    assert_not_nil human.face
    assert_equal face.description, human.face.description, "Description of face should be the same before changes to child instance"
    face.description = "gormless"
    assert_equal face.description, human.face.description, "Description of face should be the same after changes to child instance"
    human.face.description = "pleasing"
    assert_equal face.description, human.face.description, "Description of face should be the same after changes to newly-created-parent-owned instance"
  end

  def test_should_not_try_to_set_inverse_instances_when_the_inverse_is_a_has_many
    interest = interests(:trainspotting)
    human = interest.human
    assert_not_nil human.interests
    iz = human.interests.detect { |_iz| _iz.id == interest.id }
    assert_not_nil iz
    assert_equal interest.topic, iz.topic, "Interest topics should be the same before changes to child"
    interest.topic = "Eating cheese with a spoon"
    assert_not_equal interest.topic, iz.topic, "Interest topics should not be the same after changes to child"
    iz.topic = "Cow tipping"
    assert_not_equal interest.topic, iz.topic, "Interest topics should not be the same after changes to parent-owned instance"
  end

  def test_with_has_many_inversing_should_try_to_set_inverse_instances_when_the_inverse_is_a_has_many
    with_has_many_inversing(Interest) do
      interest = interests(:trainspotting)
      human = interest.human
      assert_not_nil human.interests
      iz = human.interests.detect { |_iz| _iz.id == interest.id }
      assert_not_nil iz
      assert_equal interest.topic, iz.topic, "Interest topics should be the same before changes to child"
      interest.topic = "Eating cheese with a spoon"
      assert_equal interest.topic, iz.topic, "Interest topics should be the same after changes to child"
      iz.topic = "Cow tipping"
      assert_equal interest.topic, iz.topic, "Interest topics should be the same after changes to parent-owned instance"
    end
  end

  def test_with_has_many_inversing_should_have_single_record_when_setting_record_through_attribute_in_build_method
    with_has_many_inversing(Interest) do
      human = Human.create!
      human.interests.build(
        human: human
      )
      assert_equal 1, human.interests.size
      human.save!
      assert_equal 1, human.interests.size
    end
  end

  def test_with_has_many_inversing_does_not_trigger_association_callbacks_on_set_when_the_inverse_is_a_has_many
    with_has_many_inversing(Interest) do
      human = interests(:trainspotting).human_with_callbacks
      assert_not_predicate human, :add_callback_called?
    end
  end

  def test_with_hash_many_inversing_does_not_add_duplicate_associated_objects
    with_has_many_inversing(Interest) do
      human = Human.new
      interest = Interest.new(human: human)
      human.interests << interest
      assert_equal 1, human.interests.size
    end
  end

  def test_recursive_model_has_many_inversing
    with_has_many_inversing do
      main = Branch.create!
      feature = main.branches.create!
      topic = feature.branches.build

      assert_equal(main, topic.branch.branch)
    end
  end

  def test_recursive_inverse_on_recursive_model_has_many_inversing
    with_has_many_inversing do
      main = BrokenBranch.create!
      feature = main.branches.create!
      topic = feature.branches.build

      error = assert_raises(ActiveRecord::InverseOfAssociationRecursiveError) do
        topic.branch.branch
      end

      assert_equal("Inverse association branch (:branch in BrokenBranch) is recursive.", error.message)
    end
  end

  def test_unscope_does_not_set_inverse_when_incorrect
    interest = interests(:trainspotting)
    human = interest.human
    created_human = Human.create(name: "wrong human")
    found_interest = created_human.interests.or(human.interests).detect { |this_interest| interest.id == this_interest.id }

    assert_equal human, found_interest.human
  end

  def test_or_does_not_set_inverse_when_incorrect
    interest = interests(:trainspotting)
    human = interest.human
    created_human = Human.create(name: "wrong human")
    found_interest = created_human.interests.unscope(:where).detect { |this_interest| interest.id == this_interest.id }

    assert_equal human, found_interest.human
  end

  def test_child_instance_should_be_shared_with_replaced_via_accessor_parent
    face = Face.first
    human = Human.new(name: "Charles")
    face.human = human
    assert_not_nil human.face
    assert_equal face.description, human.face.description, "Description of face should be the same before changes to child instance"
    face.description = "gormless"
    assert_equal face.description, human.face.description, "Description of face should be the same after changes to child instance"
    human.face.description = "pleasing"
    assert_equal face.description, human.face.description, "Description of face should be the same after changes to replaced-parent-owned instance"
  end

  def test_trying_to_use_inverses_that_dont_exist_should_raise_an_error
    assert_raise(ActiveRecord::InverseOfAssociationNotFoundError) { Face.first.confused_human }
  end

  def test_trying_to_use_inverses_that_dont_exist_should_have_suggestions_for_fix
    error = assert_raise(ActiveRecord::InverseOfAssociationNotFoundError) {
      Face.first.confused_human
    }

    assert_match "Did you mean?", error.message
    assert_equal "confused_face", error.corrections.first
  end

  def test_building_has_many_parent_association_inverses_one_record
    with_has_many_inversing(Interest) do
      interest = Interest.new
      interest.build_human
      assert_equal 1, interest.human.interests.size
      interest.save!
      assert_equal 1, interest.human.interests.size
    end
  end
end

class InversePolymorphicBelongsToTests < ActiveRecord::TestCase
  fixtures :humans, :faces, :interests

  def test_child_instance_should_be_shared_with_parent_on_find
    face = Face.all.merge!(where: { description: "confused" }).first
    human = face.polymorphic_human
    assert_equal face.description, human.polymorphic_face.description, "Description of face should be the same before changes to child instance"
    face.description = "gormless"
    assert_equal face.description, human.polymorphic_face.description, "Description of face should be the same after changes to child instance"
    human.polymorphic_face.description = "pleasing"
    assert_equal face.description, human.polymorphic_face.description, "Description of face should be the same after changes to parent-owned instance"
  end

  def test_eager_loaded_child_instance_should_be_shared_with_parent_on_find
    face = Face.all.merge!(where: { description: "confused" }, includes: :human).first
    human = face.polymorphic_human
    assert_equal face.description, human.polymorphic_face.description, "Description of face should be the same before changes to child instance"
    face.description = "gormless"
    assert_equal face.description, human.polymorphic_face.description, "Description of face should be the same after changes to child instance"
    human.polymorphic_face.description = "pleasing"
    assert_equal face.description, human.polymorphic_face.description, "Description of face should be the same after changes to parent-owned instance"

    face = Face.all.merge!(where: { description: "confused" }, includes: :human, order: "humans.id").first
    human = face.polymorphic_human
    assert_equal face.description, human.polymorphic_face.description, "Description of face should be the same before changes to child instance"
    face.description = "gormless"
    assert_equal face.description, human.polymorphic_face.description, "Description of face should be the same after changes to child instance"
    human.polymorphic_face.description = "pleasing"
    assert_equal face.description, human.polymorphic_face.description, "Description of face should be the same after changes to parent-owned instance"
  end

  def test_child_instance_should_be_shared_with_replaced_via_accessor_parent
    face = faces(:confused)
    new_human = Human.new

    assert_not_nil face.polymorphic_human
    face.polymorphic_human = new_human

    assert_equal face.description, new_human.polymorphic_face.description, "Description of face should be the same before changes to parent instance"
    face.description = "Bongo"
    assert_equal face.description, new_human.polymorphic_face.description, "Description of face should be the same after changes to parent instance"
    new_human.polymorphic_face.description = "Mungo"
    assert_equal face.description, new_human.polymorphic_face.description, "Description of face should be the same after changes to replaced-parent-owned instance"
  end

  def test_inversed_instance_should_not_be_reloaded_after_stale_state_changed
    new_human = Human.new
    face = Face.new
    new_human.face = face

    old_inversed_human = face.human
    new_human.save!
    new_inversed_human = face.human

    assert_same old_inversed_human, new_inversed_human
  end

  def test_inversed_instance_should_not_be_reloaded_after_stale_state_changed_with_validation
    face = Face.new human: Human.new

    old_inversed_human = face.human
    face.save!
    new_inversed_human = face.human

    assert_same old_inversed_human, new_inversed_human
  end

  def test_inversed_instance_should_load_after_autosave_if_it_is_not_already_loaded
    human = Human.create!
    human.create_autosave_face!

    human.autosave_face.reload # clear cached load of autosave_human
    human.autosave_face.description = "new description"
    human.save!

    assert_not_nil human.autosave_face.autosave_human
  end

  def test_should_not_try_to_set_inverse_instances_when_the_inverse_is_a_has_many
    interest = interests(:llama_wrangling)
    human = interest.polymorphic_human
    assert_not_nil human.polymorphic_interests
    iz = human.polymorphic_interests.detect { |_iz| _iz.id == interest.id }
    assert_not_nil iz
    assert_equal interest.topic, iz.topic, "Interest topics should be the same before changes to child"
    interest.topic = "Eating cheese with a spoon"
    assert_not_equal interest.topic, iz.topic, "Interest topics should not be the same after changes to child"
    iz.topic = "Cow tipping"
    assert_not_equal interest.topic, iz.topic, "Interest topics should not be the same after changes to parent-owned instance"
  end

  def test_with_has_many_inversing_should_try_to_set_inverse_instances_when_the_inverse_is_a_has_many
    with_has_many_inversing(Interest) do
      interest = interests(:llama_wrangling)
      human = interest.polymorphic_human
      assert_not_nil human.polymorphic_interests
      iz = human.polymorphic_interests.detect { |_iz| _iz.id == interest.id }
      assert_not_nil iz
      assert_equal interest.topic, iz.topic, "Interest topics should be the same before changes to child"
      interest.topic = "Eating cheese with a spoon"
      assert_equal interest.topic, iz.topic, "Interest topics should be the same after changes to child"
      iz.topic = "Cow tipping"
      assert_equal interest.topic, iz.topic, "Interest topics should be the same after changes to parent-owned instance"
    end
  end

  def test_with_has_many_inversing_does_not_trigger_association_callbacks_on_set_when_the_inverse_is_a_has_many
    with_has_many_inversing(Interest) do
      human = interests(:llama_wrangling).polymorphic_human_with_callbacks
      assert_not_predicate human, :add_callback_called?
    end
  end

  def test_trying_to_access_inverses_that_dont_exist_shouldnt_raise_an_error
    # Ideally this would, if only for symmetry's sake with other association types
    assert_nothing_raised { Face.first.puzzled_polymorphic_human }
  end

  def test_trying_to_set_polymorphic_inverses_that_dont_exist_at_all_should_raise_an_error
    # fails because no class has the correct inverse_of for puzzled_polymorphic_human
    assert_raise(ActiveRecord::InverseOfAssociationNotFoundError) { Face.first.puzzled_polymorphic_human = Human.first }
  end

  def test_trying_to_set_polymorphic_inverses_that_dont_exist_on_the_instance_being_set_should_raise_an_error
    # passes because Human does have the correct inverse_of
    assert_nothing_raised { Face.first.polymorphic_human = Human.first }
    # fails because Interest does have the correct inverse_of
    assert_raise(ActiveRecord::InverseOfAssociationNotFoundError) { Face.first.polymorphic_human = Interest.first }
  end
end

# NOTE - these tests might not be meaningful, ripped as they were from the parental_control plugin
# which would guess the inverse rather than look for an explicit configuration option.
class InverseMultipleHasManyInversesForSameModel < ActiveRecord::TestCase
  fixtures :humans, :interests, :zines

  def test_that_we_can_load_associations_that_have_the_same_reciprocal_name_from_different_models
    assert_nothing_raised do
      interest = Interest.first
      interest.zine
      interest.human
    end
  end

  def test_that_we_can_create_associations_that_have_the_same_reciprocal_name_from_different_models
    assert_nothing_raised do
      interest = Interest.first
      interest.build_zine(title: "Get Some in Winter! 2008")
      interest.build_human(name: "Gordon")
      interest.save!
    end
  end
end
