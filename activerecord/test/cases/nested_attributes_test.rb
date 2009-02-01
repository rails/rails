require "cases/helper"
require "models/pirate"
require "models/ship"
require "models/bird"
require "models/parrot"
require "models/treasure"

module AssertRaiseWithMessage
  def assert_raise_with_message(expected_exception, expected_message)
    begin
      error_raised = false
      yield
    rescue expected_exception => error
      error_raised = true
      actual_message = error.message
    end
    assert error_raised
    assert_equal expected_message, actual_message
  end
end

class TestNestedAttributesInGeneral < ActiveRecord::TestCase
  include AssertRaiseWithMessage

  def teardown
    Pirate.accepts_nested_attributes_for :ship, :allow_destroy => true
  end

  def test_base_should_have_an_empty_reject_new_nested_attributes_procs
    assert_equal Hash.new, ActiveRecord::Base.reject_new_nested_attributes_procs
  end

  def test_should_add_a_proc_to_reject_new_nested_attributes_procs
    [:parrots, :birds].each do |name|
      assert_instance_of Proc, Pirate.reject_new_nested_attributes_procs[name]
    end
  end

  def test_should_raise_an_ArgumentError_for_non_existing_associations
    assert_raise_with_message ArgumentError, "No association found for name `honesty'. Has it been defined yet?" do
      Pirate.accepts_nested_attributes_for :honesty
    end
  end

  def test_should_disable_allow_destroy_by_default
    Pirate.accepts_nested_attributes_for :ship

    pirate = Pirate.create!(:catchphrase => "Don' botharrr talkin' like one, savvy?")
    ship = pirate.create_ship(:name => 'Nights Dirty Lightning')

    assert_no_difference('Ship.count') do
      pirate.update_attributes(:ship_attributes => { '_delete' => true })
    end
  end

  def test_a_model_should_respond_to_underscore_delete_and_return_if_it_is_marked_for_destruction
    ship = Ship.create!(:name => 'Nights Dirty Lightning')
    assert !ship._delete
    ship.mark_for_destruction
    assert ship._delete
  end
end

class TestNestedAttributesOnAHasOneAssociation < ActiveRecord::TestCase
  def setup
    @pirate = Pirate.create!(:catchphrase => "Don' botharrr talkin' like one, savvy?")
    @ship = @pirate.create_ship(:name => 'Nights Dirty Lightning')
  end

  def test_should_define_an_attribute_writer_method_for_the_association
    assert_respond_to @pirate, :ship_attributes=
  end

  def test_should_automatically_instantiate_an_associated_model_if_there_is_none
    @ship.destroy
    @pirate.reload.ship_attributes = { :name => 'Davy Jones Gold Dagger' }

    assert @pirate.ship.new_record?
    assert_equal 'Davy Jones Gold Dagger', @pirate.ship.name
  end

  def test_should_take_a_hash_and_assign_the_attributes_to_the_existing_associated_model
    @pirate.ship_attributes = { :name => 'Davy Jones Gold Dagger' }
    assert !@pirate.ship.new_record?
    assert_equal 'Davy Jones Gold Dagger', @pirate.ship.name
  end

  def test_should_also_work_with_a_HashWithIndifferentAccess
    @pirate.ship_attributes = HashWithIndifferentAccess.new(:name => 'Davy Jones Gold Dagger')
    assert !@pirate.ship.new_record?
    assert_equal 'Davy Jones Gold Dagger', @pirate.ship.name
  end

  def test_should_work_with_update_attributes_as_well
    @pirate.update_attributes({ :catchphrase => 'Arr', :ship_attributes => { :name => 'Mister Pablo' } })
    @pirate.reload

    assert_equal 'Arr', @pirate.catchphrase
    assert_equal 'Mister Pablo', @pirate.ship.name
  end

  def test_should_be_possible_to_destroy_the_associated_model
    @pirate.ship.destroy
    ['1', 1, 'true', true].each do |true_variable|
      @pirate.reload.create_ship(:name => 'Mister Pablo')
      assert_difference('Ship.count', -1) do
        @pirate.update_attributes(:ship_attributes => { '_delete' => true_variable })
      end
    end
  end

  def test_should_not_destroy_the_associated_model_with_a_non_truthy_argument
    [nil, '0', 0, 'false', false].each do |false_variable|
      assert_no_difference('Ship.count') do
        @pirate.update_attributes(:ship_attributes => { '_delete' => false_variable })
      end
    end
  end

  def test_should_not_destroy_the_associated_model_until_the_parent_is_saved
    assert_no_difference('Ship.count') do
      @pirate.attributes = { :ship_attributes => { '_delete' => true } }
    end
    assert_difference('Ship.count', -1) { @pirate.save }
  end

  def test_should_automatically_enable_autosave_on_the_association
    assert Pirate.reflect_on_association(:ship).options[:autosave]
  end
end

class TestNestedAttributesOnABelongsToAssociation < ActiveRecord::TestCase
  def setup
    @ship = Ship.create!(:name => 'Nights Dirty Lightning')
    @pirate = @ship.create_pirate(:catchphrase => "Don' botharrr talkin' like one, savvy?")
  end

  def test_should_define_an_attribute_writer_method_for_the_association
    assert_respond_to @ship, :pirate_attributes=
  end

  def test_should_automatically_instantiate_an_associated_model_if_there_is_none
    @pirate.destroy
    @ship.reload.pirate_attributes = { :catchphrase => 'Arr' }

    assert @ship.pirate.new_record?
    assert_equal 'Arr', @ship.pirate.catchphrase
  end

  def test_should_take_a_hash_and_assign_the_attributes_to_the_existing_associated_model
    @ship.pirate_attributes = { :catchphrase => 'Arr' }
    assert !@ship.pirate.new_record?
    assert_equal 'Arr', @ship.pirate.catchphrase
  end

  def test_should_also_work_with_a_HashWithIndifferentAccess
    @ship.pirate_attributes = HashWithIndifferentAccess.new(:catchphrase => 'Arr')
    assert !@ship.pirate.new_record?
    assert_equal 'Arr', @ship.pirate.catchphrase
  end

  def test_should_work_with_update_attributes_as_well
    @ship.update_attributes({ :name => 'Mister Pablo', :pirate_attributes => { :catchphrase => 'Arr' } })
    @ship.reload

    assert_equal 'Mister Pablo', @ship.name
    assert_equal 'Arr', @ship.pirate.catchphrase
  end

  def test_should_be_possible_to_destroy_the_associated_model
    @ship.pirate.destroy
    ['1', 1, 'true', true].each do |true_variable|
      @ship.reload.create_pirate(:catchphrase => 'Arr')
      assert_difference('Pirate.count', -1) do
        @ship.update_attributes(:pirate_attributes => { '_delete' => true_variable })
      end
    end
  end

  def test_should_not_destroy_the_associated_model_with_a_non_truthy_argument
    [nil, '', '0', 0, 'false', false].each do |false_variable|
      assert_no_difference('Pirate.count') do
        @ship.update_attributes(:pirate_attributes => { '_delete' => false_variable })
      end
    end
  end

  def test_should_not_destroy_the_associated_model_until_the_parent_is_saved
    assert_no_difference('Pirate.count') do
      @ship.attributes = { :pirate_attributes => { '_delete' => true } }
    end
    assert_difference('Pirate.count', -1) { @ship.save }
  end

  def test_should_automatically_enable_autosave_on_the_association
    assert Ship.reflect_on_association(:pirate).options[:autosave]
  end
end

module NestedAttributesOnACollectionAssociationTests
  include AssertRaiseWithMessage

  def test_should_define_an_attribute_writer_method_for_the_association
    assert_respond_to @pirate, association_setter
  end

  def test_should_take_a_hash_with_string_keys_and_assign_the_attributes_to_the_associated_models
    @alternate_params[association_getter].stringify_keys!
    @pirate.update_attributes @alternate_params
    assert_equal ['Grace OMalley', 'Privateers Greed'], [@child_1.reload.name, @child_2.reload.name]
  end

  def test_should_also_work_with_a_HashWithIndifferentAccess
    @pirate.send(association_setter, HashWithIndifferentAccess.new(@child_1.id => HashWithIndifferentAccess.new(:name => 'Grace OMalley')))
    @pirate.save
    assert_equal 'Grace OMalley', @child_1.reload.name
  end

  def test_should_take_a_hash_with_integer_keys_and_assign_the_attributes_to_the_associated_models
    @pirate.attributes = @alternate_params
    assert_equal 'Grace OMalley', @pirate.send(@association_name).first.name
    assert_equal 'Privateers Greed', @pirate.send(@association_name).last.name
  end

  def test_should_automatically_build_new_associated_models_for_each_entry_in_a_hash_where_the_id_starts_with_the_string_new_
    @pirate.send(@association_name).destroy_all
    @pirate.reload.attributes = { association_getter => { 'new_1' => { :name => 'Grace OMalley' }, 'new_2' => { :name => 'Privateers Greed' }}}

    assert @pirate.send(@association_name).first.new_record?
    assert_equal 'Grace OMalley', @pirate.send(@association_name).first.name

    assert @pirate.send(@association_name).last.new_record?
    assert_equal 'Privateers Greed', @pirate.send(@association_name).last.name
  end

  def test_should_sort_the_hash_by_the_keys_before_building_new_associated_models
    attributes = ActiveSupport::OrderedHash.new
    attributes['new_123726353'] = { :name => 'Grace OMalley' }
    attributes['new_2'] = { :name => 'Privateers Greed' } # 2 is lower then 123726353
    @pirate.send(association_setter, attributes)

    assert_equal ['Posideons Killer', 'Killer bandita Dionne', 'Privateers Greed', 'Grace OMalley'].to_set, @pirate.send(@association_name).map(&:name).to_set
  end

  def test_should_raise_an_argument_error_if_something_else_than_a_hash_is_passed
    assert_nothing_raised(ArgumentError) { @pirate.send(association_setter, {}) }
    assert_nothing_raised(ArgumentError) { @pirate.send(association_setter, ActiveSupport::OrderedHash.new) }

    assert_raise_with_message ArgumentError, 'Hash expected, got String ("foo")' do
      @pirate.send(association_setter, "foo")
    end
    assert_raise_with_message ArgumentError, 'Hash expected, got Array ([:foo, :bar])' do
      @pirate.send(association_setter, [:foo, :bar])
    end
  end

  def test_should_work_with_update_attributes_as_well
    @pirate.update_attributes({ :catchphrase => 'Arr', association_getter => { @child_1.id => { :name => 'Grace OMalley' }}})
    assert_equal 'Grace OMalley', @child_1.reload.name
  end

  def test_should_automatically_reject_any_new_record_if_a_reject_if_proc_exists_and_returns_false
    @alternate_params[association_getter]["new_12345"] = {}
    assert_no_difference("@pirate.send(@association_name).length") do
      @pirate.attributes = @alternate_params
    end
  end

  def test_should_update_existing_records_and_add_new_ones_that_have_an_id_that_start_with_the_string_new_
    @alternate_params[association_getter]['new_12345'] = { :name => 'Buccaneers Servant' }
    assert_difference('@pirate.send(@association_name).count', +1) do
      @pirate.update_attributes @alternate_params
    end
    assert_equal ['Grace OMalley', 'Privateers Greed', 'Buccaneers Servant'].to_set, @pirate.reload.send(@association_name).map(&:name).to_set
  end

  def test_should_be_possible_to_destroy_a_record
    ['1', 1, 'true', true].each do |true_variable|
      record = @pirate.reload.send(@association_name).create!(:name => 'Grace OMalley')
      @pirate.send(association_setter,
        @alternate_params[association_getter].merge(record.id => { '_delete' => true_variable })
      )

      assert_difference('@pirate.send(@association_name).count', -1) do
        @pirate.save
      end
    end
  end

  def test_should_not_destroy_the_associated_model_with_a_non_truthy_argument
    [nil, '', '0', 0, 'false', false].each do |false_variable|
      @alternate_params[association_getter][@child_1.id]['_delete'] = false_variable
      assert_no_difference('@pirate.send(@association_name).count') do
        @pirate.update_attributes(@alternate_params)
      end
    end
  end

  def test_should_not_destroy_the_associated_model_until_the_parent_is_saved
    assert_no_difference('@pirate.send(@association_name).count') do
      @pirate.send(association_setter, @alternate_params[association_getter].merge(@child_1.id => { '_delete' => true }))
    end
    assert_difference('@pirate.send(@association_name).count', -1) { @pirate.save }
  end

  def test_should_automatically_enable_autosave_on_the_association
    assert Pirate.reflect_on_association(@association_name).options[:autosave]
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

    @pirate = Pirate.create!(:catchphrase => "Don' botharrr talkin' like one, savvy?")
    @child_1 = @pirate.birds.create!(:name => 'Posideons Killer')
    @child_2 = @pirate.birds.create!(:name => 'Killer bandita Dionne')

    @alternate_params = {
      :birds_attributes => {
        @child_1.id => { :name => 'Grace OMalley' },
        @child_2.id => { :name => 'Privateers Greed' }
      }
    }
  end

  include NestedAttributesOnACollectionAssociationTests
end

class TestNestedAttributesOnAHasAndBelongsToManyAssociation < ActiveRecord::TestCase
  def setup
    @association_type = :has_and_belongs_to_many
    @association_name = :parrots

    @pirate = Pirate.create!(:catchphrase => "Don' botharrr talkin' like one, savvy?")
    @child_1 = @pirate.parrots.create!(:name => 'Posideons Killer')
    @child_2 = @pirate.parrots.create!(:name => 'Killer bandita Dionne')

    @alternate_params = {
      :parrots_attributes => {
        @child_1.id => { :name => 'Grace OMalley' },
        @child_2.id => { :name => 'Privateers Greed' }
      }
    }
  end

  include NestedAttributesOnACollectionAssociationTests
end