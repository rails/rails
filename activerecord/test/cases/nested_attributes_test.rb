# frozen_string_literal: true

require "cases/helper"
require "models/pirate"
require "models/ship"
require "models/ship_part"
require "models/bird"
require "models/parrot"
require "models/treasure"
require "models/man"
require "models/interest"
require "models/owner"
require "models/pet"
require "active_support/hash_with_indifferent_access"

class TestNestedAttributesInGeneral < ActiveRecord::TestCase
  teardown do
    Pirate.accepts_nested_attributes_for :ship, allow_destroy: true, reject_if: proc(&:empty?)
  end

  def test_base_should_have_an_empty_nested_attributes_options
    assert_equal Hash.new, ActiveRecord::Base.nested_attributes_options
  end

  def test_should_add_a_proc_to_nested_attributes_options
    assert_equal ActiveRecord::NestedAttributes::ClassMethods::REJECT_ALL_BLANK_PROC,
                 Pirate.nested_attributes_options[:birds_with_reject_all_blank][:reject_if]

    [:parrots, :birds].each do |name|
      assert_instance_of Proc, Pirate.nested_attributes_options[name][:reject_if]
    end
  end

  def test_should_not_build_a_new_record_using_reject_all_even_if_destroy_is_given
    pirate = Pirate.create!(catchphrase: "Don' botharrr talkin' like one, savvy?")
    pirate.birds_with_reject_all_blank_attributes = [{ name: "", color: "", _destroy: "0" }]
    pirate.save!

    assert pirate.birds_with_reject_all_blank.empty?
  end

  def test_should_not_build_a_new_record_if_reject_all_blank_returns_false
    pirate = Pirate.create!(catchphrase: "Don' botharrr talkin' like one, savvy?")
    pirate.birds_with_reject_all_blank_attributes = [{ name: "", color: "" }]
    pirate.save!

    assert pirate.birds_with_reject_all_blank.empty?
  end

  def test_should_build_a_new_record_if_reject_all_blank_does_not_return_false
    pirate = Pirate.create!(catchphrase: "Don' botharrr talkin' like one, savvy?")
    pirate.birds_with_reject_all_blank_attributes = [{ name: "Tweetie", color: "" }]
    pirate.save!

    assert_equal 1, pirate.birds_with_reject_all_blank.count
    assert_equal "Tweetie", pirate.birds_with_reject_all_blank.first.name
  end

  def test_should_raise_an_ArgumentError_for_non_existing_associations
    exception = assert_raise ArgumentError do
      Pirate.accepts_nested_attributes_for :honesty
    end
    assert_equal "No association found for name `honesty'. Has it been defined yet?", exception.message
  end

  def test_should_raise_an_UnknownAttributeError_for_non_existing_nested_attributes
    exception = assert_raise ActiveModel::UnknownAttributeError do
      Pirate.new(ship_attributes: { sail: true })
    end
    assert_equal "unknown attribute 'sail' for Ship.", exception.message
  end

  def test_should_disable_allow_destroy_by_default
    Pirate.accepts_nested_attributes_for :ship

    pirate = Pirate.create!(catchphrase: "Don' botharrr talkin' like one, savvy?")
    ship = pirate.create_ship(name: "Nights Dirty Lightning")

    pirate.update(ship_attributes: { "_destroy" => true, :id => ship.id })

    assert_nothing_raised { pirate.ship.reload }
  end

  def test_a_model_should_respond_to_underscore_destroy_and_return_if_it_is_marked_for_destruction
    ship = Ship.create!(name: "Nights Dirty Lightning")
    assert !ship._destroy
    ship.mark_for_destruction
    assert ship._destroy
  end

  def test_reject_if_method_without_arguments
    Pirate.accepts_nested_attributes_for :ship, reject_if: :new_record?

    pirate = Pirate.new(catchphrase: "Stop wastin' me time")
    pirate.ship_attributes = { name: "Black Pearl" }
    assert_no_difference("Ship.count") { pirate.save! }
  end

  def test_reject_if_method_with_arguments
    Pirate.accepts_nested_attributes_for :ship, reject_if: :reject_empty_ships_on_create

    pirate = Pirate.new(catchphrase: "Stop wastin' me time")
    pirate.ship_attributes = { name: "Red Pearl", _reject_me_if_new: true }
    assert_no_difference("Ship.count") { pirate.save! }

    # pirate.reject_empty_ships_on_create returns false for saved pirate records
    # in the previous step note that pirate gets saved but ship fails
    pirate.ship_attributes = { name: "Red Pearl", _reject_me_if_new: true }
    assert_difference("Ship.count") { pirate.save! }
  end

  def test_reject_if_with_indifferent_keys
    Pirate.accepts_nested_attributes_for :ship, reject_if: proc { |attributes| attributes[:name].blank? }

    pirate = Pirate.new(catchphrase: "Stop wastin' me time")
    pirate.ship_attributes = { name: "Hello Pearl" }
    assert_difference("Ship.count") { pirate.save! }
  end

  def test_reject_if_with_a_proc_which_returns_true_always_for_has_one
    Pirate.accepts_nested_attributes_for :ship, reject_if: proc { |attributes| true }
    pirate = Pirate.create(catchphrase: "Stop wastin' me time")
    ship = pirate.create_ship(name: "s1")
    pirate.update(ship_attributes: { name: "s2", id: ship.id })
    assert_equal "s1", ship.reload.name
  end

  def test_reuse_already_built_new_record
    pirate = Pirate.new
    ship_built_first = pirate.build_ship
    pirate.ship_attributes = { name: "Ship 1" }
    assert_equal ship_built_first.object_id, pirate.ship.object_id
  end

  def test_do_not_allow_assigning_foreign_key_when_reusing_existing_new_record
    pirate = Pirate.create!(catchphrase: "Don' botharrr talkin' like one, savvy?")
    pirate.build_ship
    pirate.ship_attributes = { name: "Ship 1", pirate_id: pirate.id + 1 }
    assert_equal pirate.id, pirate.ship.pirate_id
  end

  def test_reject_if_with_a_proc_which_returns_true_always_for_has_many
    Man.accepts_nested_attributes_for :interests, reject_if: proc { |attributes| true }
    man = Man.create(name: "John")
    interest = man.interests.create(topic: "photography")
    man.update(interests_attributes: { topic: "gardening", id: interest.id })
    assert_equal "photography", interest.reload.topic
  end

  def test_destroy_works_independent_of_reject_if
    Man.accepts_nested_attributes_for :interests, reject_if: proc { |attributes| true }, allow_destroy: true
    man = Man.create(name: "Jon")
    interest = man.interests.create(topic: "the ladies")
    man.update(interests_attributes: { _destroy: "1", id: interest.id })
    assert man.reload.interests.empty?
  end

  def test_reject_if_is_not_short_circuited_if_allow_destroy_is_false
    Pirate.accepts_nested_attributes_for :ship, reject_if: ->(a) { a[:name] == "The Golden Hind" }, allow_destroy: false

    pirate = Pirate.create!(catchphrase: "Stop wastin' me time", ship_attributes: { name: "White Pearl", _destroy: "1" })
    assert_equal "White Pearl", pirate.reload.ship.name

    pirate.update!(ship_attributes: { id: pirate.ship.id, name: "The Golden Hind", _destroy: "1" })
    assert_equal "White Pearl", pirate.reload.ship.name

    pirate.update!(ship_attributes: { id: pirate.ship.id, name: "Black Pearl", _destroy: "1" })
    assert_equal "Black Pearl", pirate.reload.ship.name
  end

  def test_has_many_association_updating_a_single_record
    Man.accepts_nested_attributes_for(:interests)
    man = Man.create(name: "John")
    interest = man.interests.create(topic: "photography")
    man.update(interests_attributes: { topic: "gardening", id: interest.id })
    assert_equal "gardening", interest.reload.topic
  end

  def test_reject_if_with_blank_nested_attributes_id
    # When using a select list to choose an existing 'ship' id, with include_blank: true
    Pirate.accepts_nested_attributes_for :ship, reject_if: proc { |attributes| attributes[:id].blank? }

    pirate = Pirate.new(catchphrase: "Stop wastin' me time")
    pirate.ship_attributes = { id: "" }
    assert_nothing_raised { pirate.save! }
  end

  def test_first_and_array_index_zero_methods_return_the_same_value_when_nested_attributes_are_set_to_update_existing_record
    Man.accepts_nested_attributes_for(:interests)
    man = Man.create(name: "John")
    interest = man.interests.create topic: "gardening"
    man = Man.find man.id
    man.interests_attributes = [{ id: interest.id, topic: "gardening" }]
    assert_equal man.interests.first.topic, man.interests[0].topic
  end

  def test_allows_class_to_override_setter_and_call_super
    mean_pirate_class = Class.new(Pirate) do
      accepts_nested_attributes_for :parrot
      def parrot_attributes=(attrs)
        super(attrs.merge(color: "blue"))
      end
    end
    mean_pirate = mean_pirate_class.new
    mean_pirate.parrot_attributes = { name: "James" }
    assert_equal "James", mean_pirate.parrot.name
    assert_equal "blue", mean_pirate.parrot.color
  end

  def test_accepts_nested_attributes_for_can_be_overridden_in_subclasses
    Pirate.accepts_nested_attributes_for(:parrot)

    mean_pirate_class = Class.new(Pirate) do
      accepts_nested_attributes_for :parrot
    end
    mean_pirate = mean_pirate_class.new
    mean_pirate.parrot_attributes = { name: "James" }
    assert_equal "James", mean_pirate.parrot.name
  end
end

class TestNestedAttributesOnAHasOneAssociation < ActiveRecord::TestCase
  def setup
    @pirate = Pirate.create!(catchphrase: "Don' botharrr talkin' like one, savvy?")
    @ship = @pirate.create_ship(name: "Nights Dirty Lightning")
  end

  def test_should_raise_argument_error_if_trying_to_build_polymorphic_belongs_to
    exception = assert_raise ArgumentError do
      Treasure.new(name: "pearl", looter_attributes: { catchphrase: "Arrr" })
    end
    assert_equal "Cannot build association `looter'. Are you trying to build a polymorphic one-to-one association?", exception.message
  end

  def test_should_define_an_attribute_writer_method_for_the_association
    assert_respond_to @pirate, :ship_attributes=
  end

  def test_should_build_a_new_record_if_there_is_no_id
    @ship.destroy
    @pirate.reload.ship_attributes = { name: "Davy Jones Gold Dagger" }

    assert !@pirate.ship.persisted?
    assert_equal "Davy Jones Gold Dagger", @pirate.ship.name
  end

  def test_should_not_build_a_new_record_if_there_is_no_id_and_destroy_is_truthy
    @ship.destroy
    @pirate.reload.ship_attributes = { name: "Davy Jones Gold Dagger", _destroy: "1" }

    assert_nil @pirate.ship
  end

  def test_should_not_build_a_new_record_if_a_reject_if_proc_returns_false
    @ship.destroy
    @pirate.reload.ship_attributes = {}

    assert_nil @pirate.ship
  end

  def test_should_replace_an_existing_record_if_there_is_no_id
    @pirate.reload.ship_attributes = { name: "Davy Jones Gold Dagger" }

    assert !@pirate.ship.persisted?
    assert_equal "Davy Jones Gold Dagger", @pirate.ship.name
    assert_equal "Nights Dirty Lightning", @ship.name
  end

  def test_should_not_replace_an_existing_record_if_there_is_no_id_and_destroy_is_truthy
    @pirate.reload.ship_attributes = { name: "Davy Jones Gold Dagger", _destroy: "1" }

    assert_equal @ship, @pirate.ship
    assert_equal "Nights Dirty Lightning", @pirate.ship.name
  end

  def test_should_modify_an_existing_record_if_there_is_a_matching_id
    @pirate.reload.ship_attributes = { id: @ship.id, name: "Davy Jones Gold Dagger" }

    assert_equal @ship, @pirate.ship
    assert_equal "Davy Jones Gold Dagger", @pirate.ship.name
  end

  def test_should_raise_RecordNotFound_if_an_id_is_given_but_doesnt_return_a_record
    exception = assert_raise ActiveRecord::RecordNotFound do
      @pirate.ship_attributes = { id: 1234567890 }
    end
    assert_equal "Couldn't find Ship with ID=1234567890 for Pirate with ID=#{@pirate.id}", exception.message
  end

  def test_should_take_a_hash_with_string_keys_and_update_the_associated_model
    @pirate.reload.ship_attributes = { "id" => @ship.id, "name" => "Davy Jones Gold Dagger" }

    assert_equal @ship, @pirate.ship
    assert_equal "Davy Jones Gold Dagger", @pirate.ship.name
  end

  def test_should_modify_an_existing_record_if_there_is_a_matching_composite_id
    @ship.stub(:id, "ABC1X") do
      @pirate.ship_attributes = { id: @ship.id, name: "Davy Jones Gold Dagger" }

      assert_equal "Davy Jones Gold Dagger", @pirate.ship.name
    end
  end

  def test_should_destroy_an_existing_record_if_there_is_a_matching_id_and_destroy_is_truthy
    @pirate.ship.destroy

    [1, "1", true, "true"].each do |truth|
      ship = @pirate.reload.create_ship(name: "Mister Pablo")
      @pirate.update(ship_attributes: { id: ship.id, _destroy: truth })

      assert_nil @pirate.reload.ship
      assert_raise(ActiveRecord::RecordNotFound) { Ship.find(ship.id) }
    end
  end

  def test_should_not_destroy_an_existing_record_if_destroy_is_not_truthy
    [nil, "0", 0, "false", false].each do |not_truth|
      @pirate.update(ship_attributes: { id: @pirate.ship.id, _destroy: not_truth })

      assert_equal @ship, @pirate.reload.ship
    end
  end

  def test_should_not_destroy_an_existing_record_if_allow_destroy_is_false
    Pirate.accepts_nested_attributes_for :ship, allow_destroy: false, reject_if: proc(&:empty?)

    @pirate.update(ship_attributes: { id: @pirate.ship.id, _destroy: "1" })

    assert_equal @ship, @pirate.reload.ship

    Pirate.accepts_nested_attributes_for :ship, allow_destroy: true, reject_if: proc(&:empty?)
  end

  def test_should_also_work_with_a_HashWithIndifferentAccess
    @pirate.ship_attributes = ActiveSupport::HashWithIndifferentAccess.new(id: @ship.id, name: "Davy Jones Gold Dagger")

    assert @pirate.ship.persisted?
    assert_equal "Davy Jones Gold Dagger", @pirate.ship.name
  end

  def test_should_work_with_update_as_well
    @pirate.update(catchphrase: "Arr", ship_attributes: { id: @ship.id, name: "Mister Pablo" })
    @pirate.reload

    assert_equal "Arr", @pirate.catchphrase
    assert_equal "Mister Pablo", @pirate.ship.name
  end

  def test_should_not_destroy_the_associated_model_until_the_parent_is_saved
    @pirate.attributes = { ship_attributes: { id: @ship.id, _destroy: "1" } }

    assert !@pirate.ship.destroyed?
    assert @pirate.ship.marked_for_destruction?

    @pirate.save

    assert @pirate.ship.destroyed?
    assert_nil @pirate.reload.ship
  end

  def test_should_automatically_enable_autosave_on_the_association
    assert Pirate.reflect_on_association(:ship).options[:autosave]
  end

  def test_should_accept_update_only_option
    @pirate.update(update_only_ship_attributes: { id: @pirate.ship.id, name: "Mayflower" })
  end

  def test_should_create_new_model_when_nothing_is_there_and_update_only_is_true
    @ship.delete

    @pirate.reload.update(update_only_ship_attributes: { name: "Mayflower" })

    assert_not_nil @pirate.ship
  end

  def test_should_update_existing_when_update_only_is_true_and_no_id_is_given
    @ship.delete
    @ship = @pirate.create_update_only_ship(name: "Nights Dirty Lightning")

    @pirate.update(update_only_ship_attributes: { name: "Mayflower" })

    assert_equal "Mayflower", @ship.reload.name
    assert_equal @ship, @pirate.reload.ship
  end

  def test_should_update_existing_when_update_only_is_true_and_id_is_given
    @ship.delete
    @ship = @pirate.create_update_only_ship(name: "Nights Dirty Lightning")

    @pirate.update(update_only_ship_attributes: { name: "Mayflower", id: @ship.id })

    assert_equal "Mayflower", @ship.reload.name
    assert_equal @ship, @pirate.reload.ship
  end

  def test_should_destroy_existing_when_update_only_is_true_and_id_is_given_and_is_marked_for_destruction
    Pirate.accepts_nested_attributes_for :update_only_ship, update_only: true, allow_destroy: true
    @ship.delete
    @ship = @pirate.create_update_only_ship(name: "Nights Dirty Lightning")

    @pirate.update(update_only_ship_attributes: { name: "Mayflower", id: @ship.id, _destroy: true })

    assert_nil @pirate.reload.ship
    assert_raise(ActiveRecord::RecordNotFound) { Ship.find(@ship.id) }

    Pirate.accepts_nested_attributes_for :update_only_ship, update_only: true, allow_destroy: false
  end
end

class TestNestedAttributesOnABelongsToAssociation < ActiveRecord::TestCase
  def setup
    @ship = Ship.new(name: "Nights Dirty Lightning")
    @pirate = @ship.build_pirate(catchphrase: "Aye")
    @ship.save!
  end

  def test_should_define_an_attribute_writer_method_for_the_association
    assert_respond_to @ship, :pirate_attributes=
  end

  def test_should_build_a_new_record_if_there_is_no_id
    @pirate.destroy
    @ship.reload.pirate_attributes = { catchphrase: "Arr" }

    assert !@ship.pirate.persisted?
    assert_equal "Arr", @ship.pirate.catchphrase
  end

  def test_should_not_build_a_new_record_if_there_is_no_id_and_destroy_is_truthy
    @pirate.destroy
    @ship.reload.pirate_attributes = { catchphrase: "Arr", _destroy: "1" }

    assert_nil @ship.pirate
  end

  def test_should_not_build_a_new_record_if_a_reject_if_proc_returns_false
    @pirate.destroy
    @ship.reload.pirate_attributes = {}

    assert_nil @ship.pirate
  end

  def test_should_replace_an_existing_record_if_there_is_no_id
    @ship.reload.pirate_attributes = { catchphrase: "Arr" }

    assert !@ship.pirate.persisted?
    assert_equal "Arr", @ship.pirate.catchphrase
    assert_equal "Aye", @pirate.catchphrase
  end

  def test_should_not_replace_an_existing_record_if_there_is_no_id_and_destroy_is_truthy
    @ship.reload.pirate_attributes = { catchphrase: "Arr", _destroy: "1" }

    assert_equal @pirate, @ship.pirate
    assert_equal "Aye", @ship.pirate.catchphrase
  end

  def test_should_modify_an_existing_record_if_there_is_a_matching_id
    @ship.reload.pirate_attributes = { id: @pirate.id, catchphrase: "Arr" }

    assert_equal @pirate, @ship.pirate
    assert_equal "Arr", @ship.pirate.catchphrase
  end

  def test_should_raise_RecordNotFound_if_an_id_is_given_but_doesnt_return_a_record
    exception = assert_raise ActiveRecord::RecordNotFound do
      @ship.pirate_attributes = { id: 1234567890 }
    end
    assert_equal "Couldn't find Pirate with ID=1234567890 for Ship with ID=#{@ship.id}", exception.message
  end

  def test_should_take_a_hash_with_string_keys_and_update_the_associated_model
    @ship.reload.pirate_attributes = { "id" => @pirate.id, "catchphrase" => "Arr" }

    assert_equal @pirate, @ship.pirate
    assert_equal "Arr", @ship.pirate.catchphrase
  end

  def test_should_modify_an_existing_record_if_there_is_a_matching_composite_id
    @pirate.stub(:id, "ABC1X") do
      @ship.pirate_attributes = { id: @pirate.id, catchphrase: "Arr" }

      assert_equal "Arr", @ship.pirate.catchphrase
    end
  end

  def test_should_destroy_an_existing_record_if_there_is_a_matching_id_and_destroy_is_truthy
    @ship.pirate.destroy
    [1, "1", true, "true"].each do |truth|
      pirate = @ship.reload.create_pirate(catchphrase: "Arr")
      @ship.update(pirate_attributes: { id: pirate.id, _destroy: truth })
      assert_raise(ActiveRecord::RecordNotFound) { pirate.reload }
    end
  end

  def test_should_unset_association_when_an_existing_record_is_destroyed
    original_pirate_id = @ship.pirate.id
    @ship.update! pirate_attributes: { id: @ship.pirate.id, _destroy: true }

    assert_empty Pirate.where(id: original_pirate_id)
    assert_nil @ship.pirate_id
    assert_nil @ship.pirate

    @ship.reload
    assert_empty Pirate.where(id: original_pirate_id)
    assert_nil @ship.pirate_id
    assert_nil @ship.pirate
  end

  def test_should_not_destroy_an_existing_record_if_destroy_is_not_truthy
    [nil, "0", 0, "false", false].each do |not_truth|
      @ship.update(pirate_attributes: { id: @ship.pirate.id, _destroy: not_truth })
      assert_nothing_raised { @ship.pirate.reload }
    end
  end

  def test_should_not_destroy_an_existing_record_if_allow_destroy_is_false
    Ship.accepts_nested_attributes_for :pirate, allow_destroy: false, reject_if: proc(&:empty?)

    @ship.update(pirate_attributes: { id: @ship.pirate.id, _destroy: "1" })
    assert_nothing_raised { @ship.pirate.reload }
  ensure
    Ship.accepts_nested_attributes_for :pirate, allow_destroy: true, reject_if: proc(&:empty?)
  end

  def test_should_work_with_update_as_well
    @ship.update(name: "Mister Pablo", pirate_attributes: { catchphrase: "Arr" })
    @ship.reload

    assert_equal "Mister Pablo", @ship.name
    assert_equal "Arr", @ship.pirate.catchphrase
  end

  def test_should_not_destroy_the_associated_model_until_the_parent_is_saved
    pirate = @ship.pirate

    @ship.attributes = { pirate_attributes: { :id => pirate.id, "_destroy" => true } }
    assert_nothing_raised { Pirate.find(pirate.id) }
    @ship.save
    assert_raise(ActiveRecord::RecordNotFound) { Pirate.find(pirate.id) }
  end

  def test_should_automatically_enable_autosave_on_the_association
    assert Ship.reflect_on_association(:pirate).options[:autosave]
  end

  def test_should_create_new_model_when_nothing_is_there_and_update_only_is_true
    @pirate.delete
    @ship.reload.attributes = { update_only_pirate_attributes: { catchphrase: "Arr" } }

    assert !@ship.update_only_pirate.persisted?
  end

  def test_should_update_existing_when_update_only_is_true_and_no_id_is_given
    @pirate.delete
    @pirate = @ship.create_update_only_pirate(catchphrase: "Aye")

    @ship.update(update_only_pirate_attributes: { catchphrase: "Arr" })
    assert_equal "Arr", @pirate.reload.catchphrase
    assert_equal @pirate, @ship.reload.update_only_pirate
  end

  def test_should_update_existing_when_update_only_is_true_and_id_is_given
    @pirate.delete
    @pirate = @ship.create_update_only_pirate(catchphrase: "Aye")

    @ship.update(update_only_pirate_attributes: { catchphrase: "Arr", id: @pirate.id })

    assert_equal "Arr", @pirate.reload.catchphrase
    assert_equal @pirate, @ship.reload.update_only_pirate
  end

  def test_should_destroy_existing_when_update_only_is_true_and_id_is_given_and_is_marked_for_destruction
    Ship.accepts_nested_attributes_for :update_only_pirate, update_only: true, allow_destroy: true
    @pirate.delete
    @pirate = @ship.create_update_only_pirate(catchphrase: "Aye")

    @ship.update(update_only_pirate_attributes: { catchphrase: "Arr", id: @pirate.id, _destroy: true })

    assert_raise(ActiveRecord::RecordNotFound) { @pirate.reload }

    Ship.accepts_nested_attributes_for :update_only_pirate, update_only: true, allow_destroy: false
  end
end

module NestedAttributesOnACollectionAssociationTests
  def test_should_define_an_attribute_writer_method_for_the_association
    assert_respond_to @pirate, association_setter
  end

  def test_should_raise_an_UnknownAttributeError_for_non_existing_nested_attributes_for_has_many
    exception = assert_raise ActiveModel::UnknownAttributeError do
      @pirate.parrots_attributes = [{ peg_leg: true }]
    end
    assert_equal "unknown attribute 'peg_leg' for Parrot.", exception.message
  end

  def test_should_save_only_one_association_on_create
    pirate = Pirate.create!(
      :catchphrase => "Arr",
      association_getter => { "foo" => { name: "Grace OMalley" } })

    assert_equal 1, pirate.reload.send(@association_name).count
  end

  def test_should_take_a_hash_with_string_keys_and_assign_the_attributes_to_the_associated_models
    @alternate_params[association_getter].stringify_keys!
    @pirate.update @alternate_params
    assert_equal ["Grace OMalley", "Privateers Greed"], [@child_1.reload.name, @child_2.reload.name]
  end

  def test_should_take_an_array_and_assign_the_attributes_to_the_associated_models
    @pirate.send(association_setter, @alternate_params[association_getter].values)
    @pirate.save
    assert_equal ["Grace OMalley", "Privateers Greed"], [@child_1.reload.name, @child_2.reload.name]
  end

  def test_should_also_work_with_a_HashWithIndifferentAccess
    @pirate.send(association_setter, ActiveSupport::HashWithIndifferentAccess.new("foo" => ActiveSupport::HashWithIndifferentAccess.new(id: @child_1.id, name: "Grace OMalley")))
    @pirate.save
    assert_equal "Grace OMalley", @child_1.reload.name
  end

  def test_should_take_a_hash_and_assign_the_attributes_to_the_associated_models
    @pirate.attributes = @alternate_params
    assert_equal "Grace OMalley", @pirate.send(@association_name).first.name
    assert_equal "Privateers Greed", @pirate.send(@association_name).last.name
  end

  def test_should_not_load_association_when_updating_existing_records
    @pirate.reload
    @pirate.send(association_setter, [{ id: @child_1.id, name: "Grace OMalley" }])
    assert ! @pirate.send(@association_name).loaded?

    @pirate.save
    assert ! @pirate.send(@association_name).loaded?
    assert_equal "Grace OMalley", @child_1.reload.name
  end

  def test_should_not_overwrite_unsaved_updates_when_loading_association
    @pirate.reload
    @pirate.send(association_setter, [{ id: @child_1.id, name: "Grace OMalley" }])
    assert_equal "Grace OMalley", @pirate.send(@association_name).load_target.find { |r| r.id == @child_1.id }.name
  end

  def test_should_preserve_order_when_not_overwriting_unsaved_updates
    @pirate.reload
    @pirate.send(association_setter, [{ id: @child_1.id, name: "Grace OMalley" }])
    assert_equal @child_1.id, @pirate.send(@association_name).load_target.first.id
  end

  def test_should_refresh_saved_records_when_not_overwriting_unsaved_updates
    @pirate.reload
    record = @pirate.class.reflect_on_association(@association_name).klass.new(name: "Grace OMalley")
    @pirate.send(@association_name) << record
    record.save!
    @pirate.send(@association_name).last.update!(name: "Polly")
    assert_equal "Polly", @pirate.send(@association_name).load_target.last.name
  end

  def test_should_not_remove_scheduled_destroys_when_loading_association
    @pirate.reload
    @pirate.send(association_setter, [{ id: @child_1.id, _destroy: "1" }])
    assert @pirate.send(@association_name).load_target.find { |r| r.id == @child_1.id }.marked_for_destruction?
  end

  def test_should_take_a_hash_with_composite_id_keys_and_assign_the_attributes_to_the_associated_models
    @child_1.stub(:id, "ABC1X") do
      @child_2.stub(:id, "ABC2X") do

        @pirate.attributes = {
          association_getter => [
            { id: @child_1.id, name: "Grace OMalley" },
            { id: @child_2.id, name: "Privateers Greed" }
          ]
        }

        assert_equal ["Grace OMalley", "Privateers Greed"], [@child_1.name, @child_2.name]
      end
    end
  end

  def test_should_raise_RecordNotFound_if_an_id_is_given_but_doesnt_return_a_record
    exception = assert_raise ActiveRecord::RecordNotFound do
      @pirate.attributes = { association_getter => [{ id: 1234567890 }] }
    end
    assert_equal "Couldn't find #{@child_1.class.name} with ID=1234567890 for Pirate with ID=#{@pirate.id}", exception.message
  end

  def test_should_raise_RecordNotFound_if_an_id_belonging_to_a_different_record_is_given
    other_pirate = Pirate.create! catchphrase: "Ahoy!"
    other_child = other_pirate.send(@association_name).create! name: "Buccaneers Servant"

    exception = assert_raise ActiveRecord::RecordNotFound do
      @pirate.attributes = { association_getter => [{ id: other_child.id }] }
    end
    assert_equal "Couldn't find #{@child_1.class.name} with ID=#{other_child.id} for Pirate with ID=#{@pirate.id}", exception.message
  end

  def test_should_automatically_build_new_associated_models_for_each_entry_in_a_hash_where_the_id_is_missing
    @pirate.send(@association_name).destroy_all
    @pirate.reload.attributes = {
      association_getter => { "foo" => { name: "Grace OMalley" }, "bar" => { name: "Privateers Greed" } }
    }

    assert !@pirate.send(@association_name).first.persisted?
    assert_equal "Grace OMalley", @pirate.send(@association_name).first.name

    assert !@pirate.send(@association_name).last.persisted?
    assert_equal "Privateers Greed", @pirate.send(@association_name).last.name
  end

  def test_should_not_assign_destroy_key_to_a_record
    assert_nothing_raised do
      @pirate.send(association_setter, "foo" => { "_destroy" => "0" })
    end
  end

  def test_should_ignore_new_associated_records_with_truthy_destroy_attribute
    @pirate.send(@association_name).destroy_all
    @pirate.reload.attributes = {
      association_getter => {
        "foo" => { name: "Grace OMalley" },
        "bar" => { :name => "Privateers Greed", "_destroy" => "1" }
      }
    }

    assert_equal 1, @pirate.send(@association_name).length
    assert_equal "Grace OMalley", @pirate.send(@association_name).first.name
  end

  def test_should_ignore_new_associated_records_if_a_reject_if_proc_returns_false
    @alternate_params[association_getter]["baz"] = {}
    assert_no_difference("@pirate.send(@association_name).count") do
      @pirate.attributes = @alternate_params
    end
  end

  def test_should_sort_the_hash_by_the_keys_before_building_new_associated_models
    attributes = {}
    attributes["123726353"] = { name: "Grace OMalley" }
    attributes["2"] = { name: "Privateers Greed" } # 2 is lower then 123726353
    @pirate.send(association_setter, attributes)

    assert_equal ["Posideons Killer", "Killer bandita Dionne", "Privateers Greed", "Grace OMalley"].to_set, @pirate.send(@association_name).map(&:name).to_set
  end

  def test_should_raise_an_argument_error_if_something_else_than_a_hash_is_passed
    assert_nothing_raised { @pirate.send(association_setter, {}) }
    assert_nothing_raised { @pirate.send(association_setter, Hash.new) }

    exception = assert_raise ArgumentError do
      @pirate.send(association_setter, "foo")
    end
    assert_equal %{Hash or Array expected for attribute `#{@association_name}`, got String ("foo")}, exception.message
  end

  def test_should_work_with_update_as_well
    @pirate.update(catchphrase: "Arr",
      association_getter => { "foo" => { id: @child_1.id, name: "Grace OMalley" } })

    assert_equal "Grace OMalley", @child_1.reload.name
  end

  def test_should_update_existing_records_and_add_new_ones_that_have_no_id
    @alternate_params[association_getter]["baz"] = { name: "Buccaneers Servant" }
    assert_difference("@pirate.send(@association_name).count", +1) do
      @pirate.update @alternate_params
    end
    assert_equal ["Grace OMalley", "Privateers Greed", "Buccaneers Servant"].to_set, @pirate.reload.send(@association_name).map(&:name).to_set
  end

  def test_should_be_possible_to_destroy_a_record
    ["1", 1, "true", true].each do |true_variable|
      record = @pirate.reload.send(@association_name).create!(name: "Grace OMalley")
      @pirate.send(association_setter,
        @alternate_params[association_getter].merge("baz" => { :id => record.id, "_destroy" => true_variable })
      )

      assert_difference("@pirate.send(@association_name).count", -1) do
        @pirate.save
      end
    end
  end

  def test_should_not_destroy_the_associated_model_with_a_non_truthy_argument
    [nil, "", "0", 0, "false", false].each do |false_variable|
      @alternate_params[association_getter]["foo"]["_destroy"] = false_variable
      assert_no_difference("@pirate.send(@association_name).count") do
        @pirate.update(@alternate_params)
      end
    end
  end

  def test_should_not_destroy_the_associated_model_until_the_parent_is_saved
    assert_no_difference("@pirate.send(@association_name).count") do
      @pirate.send(association_setter, @alternate_params[association_getter].merge("baz" => { :id => @child_1.id, "_destroy" => true }))
    end
    assert_difference("@pirate.send(@association_name).count", -1) { @pirate.save }
  end

  def test_should_automatically_enable_autosave_on_the_association
    assert Pirate.reflect_on_association(@association_name).options[:autosave]
  end

  def test_validate_presence_of_parent_works_with_inverse_of
    Man.accepts_nested_attributes_for(:interests)
    assert_equal :man, Man.reflect_on_association(:interests).options[:inverse_of]
    assert_equal :interests, Interest.reflect_on_association(:man).options[:inverse_of]

    repair_validations(Interest) do
      Interest.validates_presence_of(:man)
      assert_difference "Man.count" do
        assert_difference "Interest.count", 2 do
          man = Man.create!(name: "John",
                            interests_attributes: [{ topic: "Cars" }, { topic: "Sports" }])
          assert_equal 2, man.interests.count
        end
      end
    end
  end

  def test_can_use_symbols_as_object_identifier
    @pirate.attributes = { parrots_attributes: { foo: { name: "Lovely Day" }, bar: { name: "Blown Away" } } }
    assert_nothing_raised { @pirate.save! }
  end

  def test_numeric_column_changes_from_zero_to_no_empty_string
    Man.accepts_nested_attributes_for(:interests)

    repair_validations(Interest) do
      Interest.validates_numericality_of(:zine_id)
      man = Man.create(name: "John")
      interest = man.interests.create(topic: "bar", zine_id: 0)
      assert interest.save
      assert !man.update(interests_attributes: { id: interest.id, zine_id: "foo" })
    end
  end

  private

    def association_setter
      @association_setter ||= "#{@association_name}_attributes=".to_sym
    end

    def association_getter
      @association_getter ||= "#{@association_name}_attributes".to_sym
    end
end

class TestNestedAttributesOnAHasManyAssociation < ActiveRecord::TestCase
  def setup
    @association_type = :has_many
    @association_name = :birds

    @pirate = Pirate.create!(catchphrase: "Don' botharrr talkin' like one, savvy?")
    @pirate.birds.create!(name: "Posideons Killer")
    @pirate.birds.create!(name: "Killer bandita Dionne")

    @child_1, @child_2 = @pirate.birds

    @alternate_params = {
      birds_attributes: {
        "foo" => { id: @child_1.id, name: "Grace OMalley" },
        "bar" => { id: @child_2.id, name: "Privateers Greed" }
      }
    }
  end

  include NestedAttributesOnACollectionAssociationTests
end

class TestNestedAttributesOnAHasAndBelongsToManyAssociation < ActiveRecord::TestCase
  def setup
    @association_type = :has_and_belongs_to_many
    @association_name = :parrots

    @pirate = Pirate.create!(catchphrase: "Don' botharrr talkin' like one, savvy?")
    @pirate.parrots.create!(name: "Posideons Killer")
    @pirate.parrots.create!(name: "Killer bandita Dionne")

    @child_1, @child_2 = @pirate.parrots

    @alternate_params = {
      parrots_attributes: {
        "foo" => { id: @child_1.id, name: "Grace OMalley" },
        "bar" => { id: @child_2.id, name: "Privateers Greed" }
      }
    }
  end

  include NestedAttributesOnACollectionAssociationTests
end

module NestedAttributesLimitTests
  def teardown
    Pirate.accepts_nested_attributes_for :parrots, allow_destroy: true, reject_if: proc(&:empty?)
  end

  def test_limit_with_less_records
    @pirate.attributes = { parrots_attributes: { "foo" => { name: "Big Big Love" } } }
    assert_difference("Parrot.count") { @pirate.save! }
  end

  def test_limit_with_number_exact_records
    @pirate.attributes = { parrots_attributes: { "foo" => { name: "Lovely Day" }, "bar" => { name: "Blown Away" } } }
    assert_difference("Parrot.count", 2) { @pirate.save! }
  end

  def test_limit_with_exceeding_records
    assert_raises(ActiveRecord::NestedAttributes::TooManyRecords) do
      @pirate.attributes = { parrots_attributes: { "foo" => { name: "Lovely Day" },
                                                      "bar" => { name: "Blown Away" },
                                                      "car" => { name: "The Happening" } } }
    end
  end
end

class TestNestedAttributesLimitNumeric < ActiveRecord::TestCase
  def setup
    Pirate.accepts_nested_attributes_for :parrots, limit: 2

    @pirate = Pirate.create!(catchphrase: "Don' botharrr talkin' like one, savvy?")
  end

  include NestedAttributesLimitTests
end

class TestNestedAttributesLimitSymbol < ActiveRecord::TestCase
  def setup
    Pirate.accepts_nested_attributes_for :parrots, limit: :parrots_limit

    @pirate = Pirate.create!(catchphrase: "Don' botharrr talkin' like one, savvy?", parrots_limit: 2)
  end

  include NestedAttributesLimitTests
end

class TestNestedAttributesLimitProc < ActiveRecord::TestCase
  def setup
    Pirate.accepts_nested_attributes_for :parrots, limit: proc { 2 }

    @pirate = Pirate.create!(catchphrase: "Don' botharrr talkin' like one, savvy?")
  end

  include NestedAttributesLimitTests
end

class TestNestedAttributesWithNonStandardPrimaryKeys < ActiveRecord::TestCase
  fixtures :owners, :pets

  def setup
    Owner.accepts_nested_attributes_for :pets, allow_destroy: true

    @owner = owners(:ashley)
    @pet1, @pet2 = pets(:chew), pets(:mochi)

    @params = {
      pets_attributes: {
        "0" => { id: @pet1.id, name: "Foo" },
        "1" => { id: @pet2.id, name: "Bar" }
      }
    }
  end

  def test_should_update_existing_records_with_non_standard_primary_key
    @owner.update(@params)
    assert_equal ["Foo", "Bar"], @owner.pets.map(&:name)
  end

  def test_attr_accessor_of_child_should_be_value_provided_during_update
    @owner = owners(:ashley)
    @pet1 = pets(:chew)
    attributes = { pets_attributes: { "1" => { id: @pet1.id,
                                                name: "Foo2",
                                                current_user: "John",
                                                _destroy: true } } }
    @owner.update(attributes)
    assert_equal "John", Pet.after_destroy_output
  end
end

class TestHasOneAutosaveAssociationWhichItselfHasAutosaveAssociations < ActiveRecord::TestCase
  self.use_transactional_tests = false unless supports_savepoints?

  def setup
    @pirate = Pirate.create!(catchphrase: "My baby takes tha mornin' train!")
    @ship = @pirate.create_ship(name: "The good ship Dollypop")
    @part = @ship.parts.create!(name: "Mast")
    @trinket = @part.trinkets.create!(name: "Necklace")
  end

  test "when great-grandchild changed in memory, saving parent should save great-grandchild" do
    @trinket.name = "changed"
    @pirate.save
    assert_equal "changed", @trinket.reload.name
  end

  test "when great-grandchild changed via attributes, saving parent should save great-grandchild" do
    @pirate.attributes = { ship_attributes: { id: @ship.id, parts_attributes: [{ id: @part.id, trinkets_attributes: [{ id: @trinket.id, name: "changed" }] }] } }
    @pirate.save
    assert_equal "changed", @trinket.reload.name
  end

  test "when great-grandchild marked_for_destruction via attributes, saving parent should destroy great-grandchild" do
    @pirate.attributes = { ship_attributes: { id: @ship.id, parts_attributes: [{ id: @part.id, trinkets_attributes: [{ id: @trinket.id, _destroy: true }] }] } }
    assert_difference("@part.trinkets.count", -1) { @pirate.save }
  end

  test "when great-grandchild added via attributes, saving parent should create great-grandchild" do
    @pirate.attributes = { ship_attributes: { id: @ship.id, parts_attributes: [{ id: @part.id, trinkets_attributes: [{ name: "created" }] }] } }
    assert_difference("@part.trinkets.count", 1) { @pirate.save }
  end

  test "when extra records exist for associations, validate (which calls nested_records_changed_for_autosave?) should not load them up" do
    @trinket.name = "changed"
    Ship.create!(pirate: @pirate, name: "The Black Rock")
    ShipPart.create!(ship: @ship, name: "Stern")
    assert_no_queries { @pirate.valid? }
  end
end

class TestHasManyAutosaveAssociationWhichItselfHasAutosaveAssociations < ActiveRecord::TestCase
  self.use_transactional_tests = false unless supports_savepoints?

  def setup
    @ship = Ship.create!(name: "The good ship Dollypop")
    @part = @ship.parts.create!(name: "Mast")
    @trinket = @part.trinkets.create!(name: "Necklace")
  end

  test "if association is not loaded and association record is saved and then in memory record attributes should be saved" do
    @ship.parts_attributes = [{ id: @part.id, name: "Deck" }]
    assert_equal 1, @ship.association(:parts).target.size
    assert_equal "Deck", @ship.parts[0].name
  end

  test "if association is not loaded and child doesn't change and I am saving a grandchild then in memory record should be used" do
    @ship.parts_attributes = [{ id: @part.id, trinkets_attributes: [{ id: @trinket.id, name: "Ruby" }] }]
    assert_equal 1, @ship.association(:parts).target.size
    assert_equal "Mast", @ship.parts[0].name
    assert_no_difference("@ship.parts[0].association(:trinkets).target.size") do
      @ship.parts[0].association(:trinkets).target.size
    end
    assert_equal "Ruby", @ship.parts[0].trinkets[0].name
    @ship.save
    assert_equal "Ruby", @ship.parts[0].trinkets[0].name
  end

  test "when grandchild changed in memory, saving parent should save grandchild" do
    @trinket.name = "changed"
    @ship.save
    assert_equal "changed", @trinket.reload.name
  end

  test "when grandchild changed via attributes, saving parent should save grandchild" do
    @ship.attributes = { parts_attributes: [{ id: @part.id, trinkets_attributes: [{ id: @trinket.id, name: "changed" }] }] }
    @ship.save
    assert_equal "changed", @trinket.reload.name
  end

  test "when grandchild marked_for_destruction via attributes, saving parent should destroy grandchild" do
    @ship.attributes = { parts_attributes: [{ id: @part.id, trinkets_attributes: [{ id: @trinket.id, _destroy: true }] }] }
    assert_difference("@part.trinkets.count", -1) { @ship.save }
  end

  test "when grandchild added via attributes, saving parent should create grandchild" do
    @ship.attributes = { parts_attributes: [{ id: @part.id, trinkets_attributes: [{ name: "created" }] }] }
    assert_difference("@part.trinkets.count", 1) { @ship.save }
  end

  test "when extra records exist for associations, validate (which calls nested_records_changed_for_autosave?) should not load them up" do
    @trinket.name = "changed"
    Ship.create!(name: "The Black Rock")
    ShipPart.create!(ship: @ship, name: "Stern")
    assert_no_queries { @ship.valid? }
  end

  test "circular references do not perform unnecessary queries" do
    ship = Ship.new(name: "The Black Rock")
    part = ship.parts.build(name: "Stern")
    ship.treasures.build(looter: part)

    assert_queries 3 do
      ship.save!
    end
  end

  test "nested singular associations are validated" do
    part = ShipPart.new(name: "Stern", ship_attributes: { name: nil })

    assert_not part.valid?
    assert_equal ["Ship name can't be blank"], part.errors.full_messages
  end
end
