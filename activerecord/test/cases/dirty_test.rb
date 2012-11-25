require 'cases/helper'
require 'models/topic'    # For booleans
require 'models/pirate'   # For timestamps
require 'models/parrot'
require 'models/person'   # For optimistic locking

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

class NumericData < ActiveRecord::Base
  self.table_name = 'numeric_data'
end

class DirtyTest < ActiveRecord::TestCase
  # Dummy to force column loads so query counts are clean.
  def setup
    Person.create :first_name => 'foo'
  end

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

  def test_time_attributes_changes_with_time_zone
    in_time_zone 'Paris' do
      target = Class.new(ActiveRecord::Base)
      target.table_name = 'pirates'

      # New record - no changes.
      pirate = target.new
      assert !pirate.created_on_changed?
      assert_nil pirate.created_on_change

      # Saved - no changes.
      pirate.catchphrase = 'arrrr, time zone!!'
      pirate.save!
      assert !pirate.created_on_changed?
      assert_nil pirate.created_on_change

      # Change created_on.
      old_created_on = pirate.created_on
      pirate.created_on = Time.now - 1.day
      assert pirate.created_on_changed?
      assert_kind_of ActiveSupport::TimeWithZone, pirate.created_on_was
      assert_equal old_created_on, pirate.created_on_was
    end
  end

  def test_setting_time_attributes_with_time_zone_field_to_itself_should_not_be_marked_as_a_change
    in_time_zone 'Paris' do
      target = Class.new(ActiveRecord::Base)
      target.table_name = 'pirates'

      pirate = target.create
      pirate.created_on = pirate.created_on
      assert !pirate.created_on_changed?
    end
  end

  def test_time_attributes_changes_without_time_zone_by_skip
    in_time_zone 'Paris' do
      target = Class.new(ActiveRecord::Base)
      target.table_name = 'pirates'

      target.skip_time_zone_conversion_for_attributes = [:created_on]

      # New record - no changes.
      pirate = target.new
      assert !pirate.created_on_changed?
      assert_nil pirate.created_on_change

      # Saved - no changes.
      pirate.catchphrase = 'arrrr, time zone!!'
      pirate.save!
      assert !pirate.created_on_changed?
      assert_nil pirate.created_on_change

      # Change created_on.
      old_created_on = pirate.created_on
      pirate.created_on = Time.now + 1.day
      assert pirate.created_on_changed?
      # kind_of does not work because
      # ActiveSupport::TimeWithZone.name == 'Time'
      assert_instance_of Time, pirate.created_on_was
      assert_equal old_created_on, pirate.created_on_was
    end
  end

  def test_time_attributes_changes_without_time_zone

    target = Class.new(ActiveRecord::Base)
    target.table_name = 'pirates'

    target.time_zone_aware_attributes = false

    # New record - no changes.
    pirate = target.new
    assert !pirate.created_on_changed?
    assert_nil pirate.created_on_change

    # Saved - no changes.
    pirate.catchphrase = 'arrrr, time zone!!'
    pirate.save!
    assert !pirate.created_on_changed?
    assert_nil pirate.created_on_change

    # Change created_on.
    old_created_on = pirate.created_on
    pirate.created_on = Time.now + 1.day
    assert pirate.created_on_changed?
    # kind_of does not work because
    # ActiveSupport::TimeWithZone.name == 'Time'
    assert_instance_of Time, pirate.created_on_was
    assert_equal old_created_on, pirate.created_on_was
  end


  def test_aliased_attribute_changes
    # the actual attribute here is name, title is an
    # alias setup via alias_attribute
    parrot = Parrot.new
    assert !parrot.title_changed?
    assert_nil parrot.title_change

    parrot.name = 'Sam'
    assert parrot.title_changed?
    assert_nil parrot.title_was
    assert_equal parrot.name_change, parrot.title_change
  end

  def test_reset_attribute!
    pirate = Pirate.create!(:catchphrase => 'Yar!')
    pirate.catchphrase = 'Ahoy!'

    pirate.reset_catchphrase!
    assert_equal "Yar!", pirate.catchphrase
    assert_equal Hash.new, pirate.changes
    assert !pirate.catchphrase_changed?
  end

  def test_nullable_number_not_marked_as_changed_if_new_value_is_blank
    pirate = Pirate.new

    ["", nil].each do |value|
      pirate.parrot_id = value
      assert !pirate.parrot_id_changed?
      assert_nil pirate.parrot_id_change
    end
  end

  def test_nullable_decimal_not_marked_as_changed_if_new_value_is_blank
    numeric_data = NumericData.new

    ["", nil].each do |value|
      numeric_data.bank_balance = value
      assert !numeric_data.bank_balance_changed?
      assert_nil numeric_data.bank_balance_change
    end
  end

  def test_nullable_float_not_marked_as_changed_if_new_value_is_blank
    numeric_data = NumericData.new

    ["", nil].each do |value|
      numeric_data.temperature = value
      assert !numeric_data.temperature_changed?
      assert_nil numeric_data.temperature_change
    end
  end

  def test_nullable_datetime_not_marked_as_changed_if_new_value_is_blank
    in_time_zone 'Edinburgh' do
      target = Class.new(ActiveRecord::Base)
      target.table_name = 'topics'

      topic = target.create
      assert_equal nil, topic.written_on

      topic.written_on = ""
      assert_equal nil, topic.written_on
      assert !topic.written_on_changed?
    end
  end

  def test_integer_zero_to_string_zero_not_marked_as_changed
    pirate = Pirate.new
    pirate.parrot_id = 0
    pirate.catchphrase = 'arrr'
    assert pirate.save!

    assert !pirate.changed?

    pirate.parrot_id = '0'
    assert !pirate.changed?
  end

  def test_integer_zero_to_integer_zero_not_marked_as_changed
    pirate = Pirate.new
    pirate.parrot_id = 0
    pirate.catchphrase = 'arrr'
    assert pirate.save!

    assert !pirate.changed?

    pirate.parrot_id = 0
    assert !pirate.changed?
  end


  def test_zero_to_blank_marked_as_changed
    pirate = Pirate.new
    pirate.catchphrase = "Yarrrr, me hearties"
    pirate.parrot_id = 1
    pirate.save

    # check the change from 1 to ''
    pirate = Pirate.find_by_catchphrase("Yarrrr, me hearties")
    pirate.parrot_id = ''
    assert pirate.parrot_id_changed?
    assert_equal([1, nil], pirate.parrot_id_change)
    pirate.save

    # check the change from nil to 0
    pirate = Pirate.find_by_catchphrase("Yarrrr, me hearties")
    pirate.parrot_id = 0
    assert pirate.parrot_id_changed?
    assert_equal([nil, 0], pirate.parrot_id_change)
    pirate.save

    # check the change from 0 to ''
    pirate = Pirate.find_by_catchphrase("Yarrrr, me hearties")
    pirate.parrot_id = ''
    assert pirate.parrot_id_changed?
    assert_equal([0, nil], pirate.parrot_id_change)
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
    pirate.parrot = Parrot.create!(:name => 'Lorre')
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

  def test_partial_update_with_optimistic_locking
    person = Person.new(:first_name => 'foo')
    old_lock_version = 1

    with_partial_updates Person, false do
      assert_queries(2) { 2.times { person.save! } }
      Person.update_all({ :first_name => 'baz' }, :id => person.id)
    end

    with_partial_updates Person, true do
      assert_queries(0) { 2.times { person.save! } }
      assert_equal old_lock_version, person.reload.lock_version

      assert_queries(1) { person.first_name = 'bar'; person.save! }
      assert_not_equal old_lock_version, person.reload.lock_version
    end
  end

  def test_changed_attributes_should_be_preserved_if_save_failure
    pirate = Pirate.new
    pirate.parrot_id = 1
    assert !pirate.save
    check_pirate_after_save_failure(pirate)

    pirate = Pirate.new
    pirate.parrot_id = 1
    assert_raise(ActiveRecord::RecordInvalid) { pirate.save! }
    check_pirate_after_save_failure(pirate)
  end

  def test_reload_should_clear_changed_attributes
    pirate = Pirate.create!(:catchphrase => "shiver me timbers")
    pirate.catchphrase = "*hic*"
    assert pirate.changed?
    pirate.reload
    assert !pirate.changed?
  end

  def test_dup_objects_should_not_copy_dirty_flag_from_creator
    pirate = Pirate.create!(:catchphrase => "shiver me timbers")
    pirate_dup = pirate.dup
    pirate_dup.reset_catchphrase!
    pirate.catchphrase = "I love Rum"
    assert pirate.catchphrase_changed?
    assert !pirate_dup.catchphrase_changed?
  end

  def test_reverted_changes_are_not_dirty
    phrase = "shiver me timbers"
    pirate = Pirate.create!(:catchphrase => phrase)
    pirate.catchphrase = "*hic*"
    assert pirate.changed?
    pirate.catchphrase = phrase
    assert !pirate.changed?
  end

  def test_reverted_changes_are_not_dirty_after_multiple_changes
    phrase = "shiver me timbers"
    pirate = Pirate.create!(:catchphrase => phrase)
    10.times do |i|
      pirate.catchphrase = "*hic*" * i
      assert pirate.changed?
    end
    assert pirate.changed?
    pirate.catchphrase = phrase
    assert !pirate.changed?
  end


  def test_reverted_changes_are_not_dirty_going_from_nil_to_value_and_back
    pirate = Pirate.create!(:catchphrase => "Yar!")

    pirate.parrot_id = 1
    assert pirate.changed?
    assert pirate.parrot_id_changed?
    assert !pirate.catchphrase_changed?

    pirate.parrot_id = nil
    assert !pirate.changed?
    assert !pirate.parrot_id_changed?
    assert !pirate.catchphrase_changed?
  end

  def test_save_should_store_serialized_attributes_even_with_partial_updates
    with_partial_updates(Topic) do
      topic = Topic.create!(:content => {:a => "a"})
      topic.content[:b] = "b"
      #assert topic.changed? # Known bug, will fail
      topic.save!
      assert_equal "b", topic.content[:b]
      topic.reload
      assert_equal "b", topic.content[:b]
    end
  end

  def test_save_always_should_update_timestamps_when_serialized_attributes_are_present
    with_partial_updates(Topic) do
      topic = Topic.create!(:content => {:a => "a"})
      topic.save!

      updated_at = topic.updated_at
      topic.content[:hello] = 'world'
      topic.save!

      assert_not_equal updated_at, topic.updated_at
      assert_equal 'world', topic.content[:hello]
    end
  end

  def test_save_should_not_save_serialized_attribute_with_partial_updates_if_not_present
    with_partial_updates(Topic) do
      Topic.create!(:author_name => 'Bill', :content => {:a => "a"})
      topic = Topic.select('id, author_name').first
      topic.update_column :author_name, 'John'
      topic = Topic.first
      assert_not_nil topic.content
    end
  end

  def test_previous_changes
    # original values should be in previous_changes
    pirate = Pirate.new

    assert_equal Hash.new, pirate.previous_changes
    pirate.catchphrase = "arrr"
    pirate.save!

    assert_equal 4, pirate.previous_changes.size
    assert_equal [nil, "arrr"], pirate.previous_changes['catchphrase']
    assert_equal [nil, pirate.id], pirate.previous_changes['id']
    assert_nil pirate.previous_changes['updated_on'][0]
    assert_not_nil pirate.previous_changes['updated_on'][1]
    assert_nil pirate.previous_changes['created_on'][0]
    assert_not_nil pirate.previous_changes['created_on'][1]
    assert !pirate.previous_changes.key?('parrot_id')

    # original values should be in previous_changes
    pirate = Pirate.new

    assert_equal Hash.new, pirate.previous_changes
    pirate.catchphrase = "arrr"
    pirate.save

    assert_equal 4, pirate.previous_changes.size
    assert_equal [nil, "arrr"], pirate.previous_changes['catchphrase']
    assert_equal [nil, pirate.id], pirate.previous_changes['id']
    assert pirate.previous_changes.include?('updated_on')
    assert pirate.previous_changes.include?('created_on')
    assert !pirate.previous_changes.key?('parrot_id')

    pirate.catchphrase = "Yar!!"
    pirate.reload
    assert_equal Hash.new, pirate.previous_changes

    pirate = Pirate.find_by_catchphrase("arrr")
    pirate.catchphrase = "Me Maties!"
    pirate.save!

    assert_equal 2, pirate.previous_changes.size
    assert_equal ["arrr", "Me Maties!"], pirate.previous_changes['catchphrase']
    assert_not_nil pirate.previous_changes['updated_on'][0]
    assert_not_nil pirate.previous_changes['updated_on'][1]
    assert !pirate.previous_changes.key?('parrot_id')
    assert !pirate.previous_changes.key?('created_on')

    pirate = Pirate.find_by_catchphrase("Me Maties!")
    pirate.catchphrase = "Thar She Blows!"
    pirate.save

    assert_equal 2, pirate.previous_changes.size
    assert_equal ["Me Maties!", "Thar She Blows!"], pirate.previous_changes['catchphrase']
    assert_not_nil pirate.previous_changes['updated_on'][0]
    assert_not_nil pirate.previous_changes['updated_on'][1]
    assert !pirate.previous_changes.key?('parrot_id')
    assert !pirate.previous_changes.key?('created_on')

    pirate = Pirate.find_by_catchphrase("Thar She Blows!")
    pirate.update_attributes(:catchphrase => "Ahoy!")

    assert_equal 2, pirate.previous_changes.size
    assert_equal ["Thar She Blows!", "Ahoy!"], pirate.previous_changes['catchphrase']
    assert_not_nil pirate.previous_changes['updated_on'][0]
    assert_not_nil pirate.previous_changes['updated_on'][1]
    assert !pirate.previous_changes.key?('parrot_id')
    assert !pirate.previous_changes.key?('created_on')

    pirate = Pirate.find_by_catchphrase("Ahoy!")
    pirate.update_attribute(:catchphrase, "Ninjas suck!")

    assert_equal 2, pirate.previous_changes.size
    assert_equal ["Ahoy!", "Ninjas suck!"], pirate.previous_changes['catchphrase']
    assert_not_nil pirate.previous_changes['updated_on'][0]
    assert_not_nil pirate.previous_changes['updated_on'][1]
    assert !pirate.previous_changes.key?('parrot_id')
    assert !pirate.previous_changes.key?('created_on')
  end

  if ActiveRecord::Base.connection.supports_migrations?
    class Testings < ActiveRecord::Base; end
    def test_field_named_field
      ActiveRecord::Base.connection.create_table :testings do |t|
        t.string :field
      end
      assert_nothing_raised do
        Testings.new.attributes
      end
    ensure
      ActiveRecord::Base.connection.drop_table :testings rescue nil
    end
  end

  def test_setting_time_attributes_with_time_zone_field_to_same_time_should_not_be_marked_as_a_change
    in_time_zone 'Paris' do
      target = Class.new(ActiveRecord::Base)
      target.table_name = 'pirates'

      created_on = Time.now

      pirate = target.create(:created_on => created_on)
      pirate.reload # Here mysql truncate the usec value to 0

      pirate.created_on = created_on
      assert !pirate.created_on_changed?
    end
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

    def in_time_zone(zone)
      old_zone  = Time.zone
      old_tz    = ActiveRecord::Base.time_zone_aware_attributes

      Time.zone = zone ? ActiveSupport::TimeZone[zone] : nil
      ActiveRecord::Base.time_zone_aware_attributes = !zone.nil?
      yield
    ensure
      Time.zone = old_zone
      ActiveRecord::Base.time_zone_aware_attributes = old_tz
    end
end
