require 'cases/helper'
require 'models/topic'    # For booleans
require 'models/pirate'   # For timestamps

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

class DirtyTest < Test::Unit::TestCase
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

  # Rewritten from original tests to use AR
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
end
