require 'cases/helper'
require 'models/topic'    # For booleans
require 'models/pirate'   # For timestamps
require 'models/parrot'

class Pirate # Just reopening it, not defining it
  attr_accessor :detected_changes_in_after_update # Boolean for if changes are detected
  attr_accessor :changes_detected_in_after_update # Actual changes

  after_update :check_changes

private
  # after_save/update in sweepers, observers, and the model itself
  # can end up checking dirty status and acting on the results
  def check_changes
    if self.changed?
      self.detected_changes_in_after_update = true
      self.changes_detected_in_after_update = self.changes
    end
  end
end

class DirtyTest < ActiveRecord::TestCase
  def test_attribute_changes
    # New record - no changes.
    pirate = Pirate.new
    assert !pirate.catchphrase_changed?
    assert_nil pirate.catchphrase_change

    # Change catchphrase.
    pirate.catchphrase = 'arrr'
    assert pirate.catchphrase_changed?
    assert_nil pirate.catchphrase_was
    assert_equal [nil, 'arrr'], pirate.catchphrase_change

    # Saved - no changes.
    pirate.save!
    assert !pirate.catchphrase_changed?
    assert_nil pirate.catchphrase_change

    # Same value - no changes.
    pirate.catchphrase = 'arrr'
    assert !pirate.catchphrase_changed?
    assert_nil pirate.catchphrase_change
  end

  def test_nullable_integer_not_marked_as_changed_if_new_value_is_blank
    pirate = Pirate.new

    ["", nil].each do |value|
      pirate.parrot_id = value
      assert !pirate.parrot_id_changed?
      assert_nil pirate.parrot_id_change
    end
  end

  def test_object_should_be_changed_if_any_attribute_is_changed
    pirate = Pirate.new
    assert !pirate.changed?
    assert_equal [], pirate.changed
    assert_equal Hash.new, pirate.changes

    pirate.catchphrase = 'arrr'
    assert pirate.changed?
    assert_nil pirate.catchphrase_was
    assert_equal %w(catchphrase), pirate.changed
    assert_equal({'catchphrase' => [nil, 'arrr']}, pirate.changes)

    pirate.save
    assert !pirate.changed?
    assert_equal [], pirate.changed
    assert_equal Hash.new, pirate.changes
  end

  def test_attribute_will_change!
    pirate = Pirate.create!(:catchphrase => 'arr')

    pirate.catchphrase << ' matey'
    assert !pirate.catchphrase_changed?

    assert pirate.catchphrase_will_change!
    assert pirate.catchphrase_changed?
    assert_equal ['arr matey', 'arr matey'], pirate.catchphrase_change

    pirate.catchphrase << '!'
    assert pirate.catchphrase_changed?
    assert_equal ['arr matey', 'arr matey!'], pirate.catchphrase_change
  end

  def test_association_assignment_changes_foreign_key
    pirate = Pirate.create!(:catchphrase => 'jarl')
    pirate.parrot = Parrot.create!
    assert pirate.changed?
    assert_equal %w(parrot_id), pirate.changed
  end

  def test_attribute_should_be_compared_with_type_cast
    topic = Topic.new
    assert topic.approved?
    assert !topic.approved_changed?

    # Coming from web form.
    params = {:topic => {:approved => 1}}
    # In the controller.
    topic.attributes = params[:topic]
    assert topic.approved?
    assert !topic.approved_changed?
  end

  def test_partial_update
    pirate = Pirate.new(:catchphrase => 'foo')
    old_updated_on = 1.hour.ago.beginning_of_day

    with_partial_updates Pirate, false do
      assert_queries(2) { 2.times { pirate.save! } }
      Pirate.update_all({ :updated_on => old_updated_on }, :id => pirate.id)
    end

    with_partial_updates Pirate, true do
      assert_queries(0) { 2.times { pirate.save! } }
      assert_equal old_updated_on, pirate.reload.updated_on

      assert_queries(1) { pirate.catchphrase = 'bar'; pirate.save! }
      assert_not_equal old_updated_on, pirate.reload.updated_on
    end
  end

  def test_changed_attributes_should_be_preserved_if_save_failure
    pirate = Pirate.new
    pirate.parrot_id = 1
    assert !pirate.save
    check_pirate_after_save_failure(pirate)

    pirate = Pirate.new
    pirate.parrot_id = 1
    assert_raises(ActiveRecord::RecordInvalid) { pirate.save! }
    check_pirate_after_save_failure(pirate)
  end

  def test_reload_should_clear_changed_attributes
    pirate = Pirate.create!(:catchphrase => "shiver me timbers")
    pirate.catchphrase = "*hic*"
    assert pirate.changed?
    pirate.reload
    assert !pirate.changed?
  end

  private
    def with_partial_updates(klass, on = true)
      old = klass.partial_updates?
      klass.partial_updates = on
      yield
    ensure
      klass.partial_updates = old
    end

    def check_pirate_after_save_failure(pirate)
      assert pirate.changed?
      assert pirate.parrot_id_changed?
      assert_equal %w(parrot_id), pirate.changed
      assert_nil pirate.parrot_id_was
    end
end
