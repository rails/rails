require "cases/helper"
require "models/pirate"
require "models/ship"
require "models/ship_part"
require "models/bird"
require "models/parrot"
require "models/treasure"

class TestAutosaveAssociationsInGeneral < ActiveRecord::TestCase
  def test_autosave_should_be_a_valid_option_for_has_one
    assert base.valid_keys_for_has_one_association.include?(:autosave)
  end

  def test_autosave_should_be_a_valid_option_for_belongs_to
    assert base.valid_keys_for_belongs_to_association.include?(:autosave)
  end

  def test_autosave_should_be_a_valid_option_for_has_many
    assert base.valid_keys_for_has_many_association.include?(:autosave)
  end

  def test_autosave_should_be_a_valid_option_for_has_and_belongs_to_many
    assert base.valid_keys_for_has_and_belongs_to_many_association.include?(:autosave)
  end

  private

  def base
    ActiveRecord::Base
  end
end

class TestDestroyAsPartOfAutosaveAssociation < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  def setup
    @pirate = Pirate.create(:catchphrase => "Don' botharrr talkin' like one, savvy?")
    @ship = @pirate.create_ship(:name => 'Nights Dirty Lightning')
  end

  # reload
  def test_a_marked_for_destruction_record_should_not_be_be_marked_after_reload
    @pirate.mark_for_destruction
    @pirate.ship.mark_for_destruction

    assert !@pirate.reload.marked_for_destruction?
    assert !@pirate.ship.marked_for_destruction?
  end

  # has_one
  def test_should_destroy_a_child_association_as_part_of_the_save_transaction_if_it_was_marked_for_destroyal
    assert !@pirate.ship.marked_for_destruction?

    @pirate.ship.mark_for_destruction
    id = @pirate.ship.id

    assert @pirate.ship.marked_for_destruction?
    assert Ship.find_by_id(id)

    @pirate.save
    assert_nil @pirate.reload.ship
    assert_nil Ship.find_by_id(id)
  end

  def test_should_rollback_destructions_if_an_exception_occurred_while_saving_a_child
    # Stub the save method of the @pirate.ship instance to destroy and then raise an exception
    class << @pirate.ship
      def save(*args)
        super
        destroy
        raise 'Oh noes!'
      end
    end

    assert_raise(RuntimeError) { assert !@pirate.save }
    assert_not_nil @pirate.reload.ship
  end

  # belongs_to
  def test_should_destroy_a_parent_association_as_part_of_the_save_transaction_if_it_was_marked_for_destroyal
    assert !@ship.pirate.marked_for_destruction?

    @ship.pirate.mark_for_destruction
    id = @ship.pirate.id

    assert @ship.pirate.marked_for_destruction?
    assert Pirate.find_by_id(id)

    @ship.save
    assert_nil @ship.reload.pirate
    assert_nil Pirate.find_by_id(id)
  end

  def test_should_rollback_destructions_if_an_exception_occurred_while_saving_a_parent
    # Stub the save method of the @ship.pirate instance to destroy and then raise an exception
    class << @ship.pirate
      def save(*args)
        super
        destroy
        raise 'Oh noes!'
      end
    end

    assert_raise(RuntimeError) { assert !@ship.save }
    assert_not_nil @ship.reload.pirate
  end

  # has_many & has_and_belongs_to
  %w{ parrots birds }.each do |association_name|
    define_method("test_should_destroy_#{association_name}_as_part_of_the_save_transaction_if_they_were_marked_for_destroyal") do
      2.times { |i| @pirate.send(association_name).create!(:name => "#{association_name}_#{i}") }

      assert !@pirate.send(association_name).any? { |child| child.marked_for_destruction? }

      @pirate.send(association_name).each { |child| child.mark_for_destruction }
      klass = @pirate.send(association_name).first.class
      ids = @pirate.send(association_name).map(&:id)

      assert @pirate.send(association_name).all? { |child| child.marked_for_destruction? }
      ids.each { |id| assert klass.find_by_id(id) }

      @pirate.save
      assert @pirate.reload.send(association_name).empty?
      ids.each { |id| assert_nil klass.find_by_id(id) }
    end

    define_method("test_should_rollback_destructions_if_an_exception_occurred_while_saving_#{association_name}") do
      2.times { |i| @pirate.send(association_name).create!(:name => "#{association_name}_#{i}") }
      before = @pirate.send(association_name).map { |c| c }

      # Stub the save method of the first child to destroy and the second to raise an exception
      class << before.first
        def save(*args)
          super
          destroy
        end
      end
      class << before.last
        def save(*args)
          super
          raise 'Oh noes!'
        end
      end

      assert_raise(RuntimeError) { assert !@pirate.save }
      assert_equal before, @pirate.reload.send(association_name)
    end
  end
end

class TestAutosaveAssociationOnAHasOneAssociation < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  def setup
    @pirate = Pirate.create(:catchphrase => "Don' botharrr talkin' like one, savvy?")
    @ship = @pirate.create_ship(:name => 'Nights Dirty Lightning')
  end

  def test_should_still_work_without_an_associated_model
    @ship.destroy
    @pirate.reload.catchphrase = "Arr"
    @pirate.save
    assert 'Arr', @pirate.reload.catchphrase
  end

  def test_should_automatically_save_the_associated_model
    @pirate.ship.name = 'The Vile Insanity'
    @pirate.save
    assert_equal 'The Vile Insanity', @pirate.reload.ship.name
  end

  def test_should_automatically_validate_the_associated_model
    @pirate.ship.name = ''
    assert !@pirate.valid?
    assert !@pirate.errors.on(:ship_name).blank?
  end

  def test_should_still_allow_to_bypass_validations_on_the_associated_model
    @pirate.catchphrase = ''
    @pirate.ship.name = ''
    @pirate.save(false)
    assert_equal ['', ''], [@pirate.reload.catchphrase, @pirate.ship.name]
  end

  def test_should_allow_to_bypass_validations_on_associated_models_at_any_depth
    2.times { |i| @pirate.ship.parts.create!(:name => "part #{i}") }

    @pirate.catchphrase = ''
    @pirate.ship.name = ''
    @pirate.ship.parts.each { |part| part.name = '' }
    @pirate.save(false)

    values = [@pirate.reload.catchphrase, @pirate.ship.name, *@pirate.ship.parts.map(&:name)]
    assert_equal ['', '', '', ''], values
  end

  def test_should_still_raise_an_ActiveRecordRecord_Invalid_exception_if_we_want_that
    @pirate.ship.name = ''
    assert_raise(ActiveRecord::RecordInvalid) do
      @pirate.save!
    end
  end

  def test_should_rollback_any_changes_if_an_exception_occurred_while_saving
    before = [@pirate.catchphrase, @pirate.ship.name]

    @pirate.catchphrase = 'Arr'
    @pirate.ship.name = 'The Vile Insanity'

    # Stub the save method of the @pirate.ship instance to raise an exception
    class << @pirate.ship
      def save(*args)
        super
        raise 'Oh noes!'
      end
    end

    assert_raise(RuntimeError) { assert !@pirate.save }
    assert_equal before, [@pirate.reload.catchphrase, @pirate.ship.name]
  end

  def test_should_not_load_the_associated_model
    assert_queries(1) { @pirate.catchphrase = 'Arr'; @pirate.save! }
  end
end

class TestAutosaveAssociationOnABelongsToAssociation < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  def setup
    @ship = Ship.create(:name => 'Nights Dirty Lightning')
    @pirate = @ship.create_pirate(:catchphrase => "Don' botharrr talkin' like one, savvy?")
  end

  def test_should_still_work_without_an_associated_model
    @pirate.destroy
    @ship.reload.name = "The Vile Insanity"
    @ship.save
    assert 'The Vile Insanity', @ship.reload.name
  end

  def test_should_automatically_save_the_associated_model
    @ship.pirate.catchphrase = 'Arr'
    @ship.save
    assert_equal 'Arr', @ship.reload.pirate.catchphrase
  end

  def test_should_automatically_validate_the_associated_model
    @ship.pirate.catchphrase = ''
    assert !@ship.valid?
    assert !@ship.errors.on(:pirate_catchphrase).blank?
  end

  def test_should_still_allow_to_bypass_validations_on_the_associated_model
    @ship.pirate.catchphrase = ''
    @ship.name = ''
    @ship.save(false)
    assert_equal ['', ''], [@ship.reload.name, @ship.pirate.catchphrase]
  end

  def test_should_still_raise_an_ActiveRecordRecord_Invalid_exception_if_we_want_that
    @ship.pirate.catchphrase = ''
    assert_raise(ActiveRecord::RecordInvalid) do
      @ship.save!
    end
  end

  def test_should_rollback_any_changes_if_an_exception_occurred_while_saving
    before = [@ship.pirate.catchphrase, @ship.name]

    @ship.pirate.catchphrase = 'Arr'
    @ship.name = 'The Vile Insanity'

    # Stub the save method of the @ship.pirate instance to raise an exception
    class << @ship.pirate
      def save(*args)
        super
        raise 'Oh noes!'
      end
    end

    assert_raise(RuntimeError) { assert !@ship.save }
    # TODO: Why does using reload on @ship looses the associated pirate?
    assert_equal before, [@ship.pirate.reload.catchphrase, @ship.reload.name]
  end

  def test_should_not_load_the_associated_model
    assert_queries(1) { @ship.name = 'The Vile Insanity'; @ship.save! }
  end
end

module AutosaveAssociationOnACollectionAssociationTests
  def test_should_automatically_save_the_associated_models
    new_names = ['Grace OMalley', 'Privateers Greed']
    @pirate.send(@association_name).each_with_index { |child, i| child.name = new_names[i] }

    @pirate.save
    assert_equal new_names, @pirate.reload.send(@association_name).map(&:name)
  end

  def test_should_automatically_validate_the_associated_models
    @pirate.send(@association_name).each { |child| child.name = '' }

    assert !@pirate.valid?
    assert_equal "can't be blank", @pirate.errors.on("#{@association_name}_name")
    assert @pirate.errors.on(@association_name).blank?
  end

  def test_should_still_allow_to_bypass_validations_on_the_associated_models
    @pirate.catchphrase = ''
    @pirate.send(@association_name).each { |child| child.name = '' }

    assert @pirate.save(false)
    assert_equal ['', '', ''], [
      @pirate.reload.catchphrase,
      @pirate.send(@association_name).first.name,
      @pirate.send(@association_name).last.name
    ]
  end

  def test_should_rollback_any_changes_if_an_exception_occurred_while_saving
    before = [@pirate.catchphrase, *@pirate.send(@association_name).map(&:name)]
    new_names = ['Grace OMalley', 'Privateers Greed']

    @pirate.catchphrase = 'Arr'
    @pirate.send(@association_name).each_with_index { |child, i| child.name = new_names[i] }

    # Stub the save method of the first child instance to raise an exception
    class << @pirate.send(@association_name).first
      def save(*args)
        super
        raise 'Oh noes!'
      end
    end

    assert_raise(RuntimeError) { assert !@pirate.save }
    assert_equal before, [@pirate.reload.catchphrase, *@pirate.send(@association_name).map(&:name)]
  end

  def test_should_still_raise_an_ActiveRecordRecord_Invalid_exception_if_we_want_that
    @pirate.send(@association_name).each { |child| child.name = '' }
    assert_raise(ActiveRecord::RecordInvalid) do
      @pirate.save!
    end
  end

  def test_should_not_load_the_associated_models_if_they_were_not_loaded_yet
    assert_queries(1) { @pirate.catchphrase = 'Arr'; @pirate.save! }

    assert_queries(2) do
      @pirate.catchphrase = 'Yarr'
      new_names = ['Grace OMalley', 'Privateers Greed']
      @pirate.send(@association_name).each_with_index { |child, i| child.name = new_names[i] }
      @pirate.save!
    end
  end
end

class TestAutosaveAssociationOnAHasManyAssociation < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  def setup
    @association_name = :birds

    @pirate = Pirate.create(:catchphrase => "Don' botharrr talkin' like one, savvy?")
    @child_1 = @pirate.birds.create(:name => 'Posideons Killer')
    @child_2 = @pirate.birds.create(:name => 'Killer bandita Dionne')
  end

  include AutosaveAssociationOnACollectionAssociationTests
end

class TestAutosaveAssociationOnAHasAndBelongsToManyAssociation < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  def setup
    @association_name = :parrots
    @habtm = true

    @pirate = Pirate.create(:catchphrase => "Don' botharrr talkin' like one, savvy?")
    @child_1 = @pirate.parrots.create(:name => 'Posideons Killer')
    @child_2 = @pirate.parrots.create(:name => 'Killer bandita Dionne')
  end

  include AutosaveAssociationOnACollectionAssociationTests
end