require 'cases/helper'
require 'models/topic'    # For booleans
require 'models/pirate'   # For timestamps
require 'models/parrot'
require 'models/person'   # For optimistic locking
require 'models/aircraft'

class Pirate # Just reopening it, not defining it
  attr_accessor :detected_changes_in_after_update # Boolean for if changes are detected
  attr_accessor :changes_detected_in_after_update # Actual changes

  after_update :check_changes

private
  # after_save/update and the model itself
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
  include InTimeZone

  # Dummy to force column loads so query counts are clean.
  def setup
    Person.create :first_name => 'foo'
  end

  def test_attribute_changes
    # New record - no changes.
    pirate = Pirate.new
    assert_equal false, pirate.catchphrase_changed?
    assert_equal false, pirate.non_validated_parrot_id_changed?

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
      pirate.created_on = old_created_on
      assert !pirate.created_on_changed?
    end
  end

  def test_setting_time_attributes_with_time_zone_field_to_itself_should_not_be_marked_as_a_change
    in_time_zone 'Paris' do
      target = Class.new(ActiveRecord::Base)
      target.table_name = 'pirates'

      pirate = target.create!
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
    with_timezone_config aware_attributes: false do
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
      pirate.created_on = Time.now + 1.day
      assert pirate.created_on_changed?
      # kind_of does not work because
      # ActiveSupport::TimeWithZone.name == 'Time'
      assert_instance_of Time, pirate.created_on_was
      assert_equal old_created_on, pirate.created_on_was
    end
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

  def test_restore_attribute!
    pirate = Pirate.create!(:catchphrase => 'Yar!')
    pirate.catchphrase = 'Ahoy!'

    pirate.restore_catchphrase!
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
      assert_nil topic.written_on

      ["", nil].each do |value|
        topic.written_on = value
        assert_nil topic.written_on
        assert !topic.written_on_changed?
      end
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

  def test_float_zero_to_string_zero_not_marked_as_changed
    data = NumericData.new :temperature => 0.0
    data.save!

    assert_not data.changed?

    data.temperature = '0'
    assert_empty data.changes

    data.temperature = '0.0'
    assert_empty data.changes

    data.temperature = '0.00'
    assert_empty data.changes
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

    assert !pirate.catchphrase_changed?
    assert pirate.catchphrase_will_change!
    assert pirate.catchphrase_changed?
    assert_equal ['arr', 'arr'], pirate.catchphrase_change

    pirate.catchphrase << ' matey!'
    assert pirate.catchphrase_changed?
    assert_equal ['arr', 'arr matey!'], pirate.catchphrase_change
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

    with_partial_writes Pirate, false do
      assert_queries(2) { 2.times { pirate.save! } }
      Pirate.where(id: pirate.id).update_all(:updated_on => old_updated_on)
    end

    with_partial_writes Pirate, true do
      assert_queries(0) { 2.times { pirate.save! } }
      assert_equal old_updated_on, pirate.reload.updated_on

      assert_queries(1) { pirate.catchphrase = 'bar'; pirate.save! }
      assert_not_equal old_updated_on, pirate.reload.updated_on
    end
  end

  def test_partial_update_with_optimistic_locking
    person = Person.new(:first_name => 'foo')
    old_lock_version = 1

    with_partial_writes Person, false do
      assert_queries(2) { 2.times { person.save! } }
      Person.where(id: person.id).update_all(:first_name => 'baz')
    end

    with_partial_writes Person, true do
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
    pirate_dup.restore_catchphrase!
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

  def test_save_should_store_serialized_attributes_even_with_partial_writes
    with_partial_writes(Topic) do
      topic = Topic.create!(:content => {:a => "a"})

      assert_not topic.changed?

      topic.content[:b] = "b"

      assert topic.changed?

      topic.save!

      assert_not topic.changed?
      assert_equal "b", topic.content[:b]

      topic.reload

      assert_equal "b", topic.content[:b]
    end
  end

  def test_save_always_should_update_timestamps_when_serialized_attributes_are_present
    with_partial_writes(Topic) do
      topic = Topic.create!(:content => {:a => "a"})
      topic.save!

      updated_at = topic.updated_at
      travel(1.second) do
        topic.content[:hello] = 'world'
        topic.save!
      end

      assert_not_equal updated_at, topic.updated_at
      assert_equal 'world', topic.content[:hello]
    end
  end

  def test_save_should_not_save_serialized_attribute_with_partial_writes_if_not_present
    with_partial_writes(Topic) do
      Topic.create!(:author_name => 'Bill', :content => {:a => "a"})
      topic = Topic.select('id, author_name').first
      topic.update_columns author_name: 'John'
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

    travel(1.second)

    pirate.catchphrase = "Me Maties!"
    pirate.save!

    assert_equal 2, pirate.previous_changes.size
    assert_equal ["arrr", "Me Maties!"], pirate.previous_changes['catchphrase']
    assert_not_nil pirate.previous_changes['updated_on'][0]
    assert_not_nil pirate.previous_changes['updated_on'][1]
    assert !pirate.previous_changes.key?('parrot_id')
    assert !pirate.previous_changes.key?('created_on')

    pirate = Pirate.find_by_catchphrase("Me Maties!")

    travel(1.second)

    pirate.catchphrase = "Thar She Blows!"
    pirate.save

    assert_equal 2, pirate.previous_changes.size
    assert_equal ["Me Maties!", "Thar She Blows!"], pirate.previous_changes['catchphrase']
    assert_not_nil pirate.previous_changes['updated_on'][0]
    assert_not_nil pirate.previous_changes['updated_on'][1]
    assert !pirate.previous_changes.key?('parrot_id')
    assert !pirate.previous_changes.key?('created_on')

    travel(1.second)

    pirate = Pirate.find_by_catchphrase("Thar She Blows!")
    pirate.update(catchphrase: "Ahoy!")

    assert_equal 2, pirate.previous_changes.size
    assert_equal ["Thar She Blows!", "Ahoy!"], pirate.previous_changes['catchphrase']
    assert_not_nil pirate.previous_changes['updated_on'][0]
    assert_not_nil pirate.previous_changes['updated_on'][1]
    assert !pirate.previous_changes.key?('parrot_id')
    assert !pirate.previous_changes.key?('created_on')

    travel(1.second)

    pirate = Pirate.find_by_catchphrase("Ahoy!")
    pirate.update_attribute(:catchphrase, "Ninjas suck!")

    assert_equal 2, pirate.previous_changes.size
    assert_equal ["Ahoy!", "Ninjas suck!"], pirate.previous_changes['catchphrase']
    assert_not_nil pirate.previous_changes['updated_on'][0]
    assert_not_nil pirate.previous_changes['updated_on'][1]
    assert !pirate.previous_changes.key?('parrot_id')
    assert !pirate.previous_changes.key?('created_on')
  ensure
    travel_back
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

  def test_datetime_attribute_can_be_updated_with_fractional_seconds
    skip "Fractional seconds are not supported" unless subsecond_precision_supported?
    in_time_zone 'Paris' do
      target = Class.new(ActiveRecord::Base)
      target.table_name = 'topics'

      written_on = Time.utc(2012, 12, 1, 12, 0, 0).in_time_zone('Paris')

      topic = target.create(:written_on => written_on)
      topic.written_on += 0.3

      assert topic.written_on_changed?, 'Fractional second update not detected'
    end
  end

  def test_datetime_attribute_doesnt_change_if_zone_is_modified_in_string
    time_in_paris = Time.utc(2014, 1, 1, 12, 0, 0).in_time_zone('Paris')
    pirate = Pirate.create!(:catchphrase => 'rrrr', :created_on => time_in_paris)

    pirate.created_on = pirate.created_on.in_time_zone('Tokyo').to_s
    assert !pirate.created_on_changed?
  end

  test "partial insert" do
    with_partial_writes Person do
      jon = nil
      assert_sql(/first_name/i) do
        jon = Person.create! first_name: 'Jon'
      end

      assert ActiveRecord::SQLCounter.log_all.none? { |sql| sql =~ /followers_count/ }

      jon.reload
      assert_equal 'Jon', jon.first_name
      assert_equal 0, jon.followers_count
      assert_not_nil jon.id
    end
  end

  test "partial insert with empty values" do
    with_partial_writes Aircraft do
      a = Aircraft.create!
      a.reload
      assert_not_nil a.id
    end
  end

  test "in place mutation detection" do
    pirate = Pirate.create!(catchphrase: "arrrr")
    pirate.catchphrase << " matey!"

    assert pirate.catchphrase_changed?
    expected_changes = {
      "catchphrase" => ["arrrr", "arrrr matey!"]
    }
    assert_equal(expected_changes, pirate.changes)
    assert_equal("arrrr", pirate.catchphrase_was)
    assert pirate.catchphrase_changed?(from: "arrrr")
    assert_not pirate.catchphrase_changed?(from: "anything else")
    assert pirate.changed_attributes.include?(:catchphrase)

    pirate.save!
    pirate.reload

    assert_equal "arrrr matey!", pirate.catchphrase
    assert_not pirate.changed?
  end

  test "in place mutation for binary" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = :binaries
      serialize :data
    end

    binary = klass.create!(data: "\\\\foo")

    assert_not binary.changed?

    binary.data = binary.data.dup

    assert_not binary.changed?

    binary = klass.last

    assert_not binary.changed?

    binary.data << "bar"

    assert binary.changed?
  end

  test "attribute_changed? doesn't compute in-place changes for unrelated attributes" do
    test_type_class = Class.new(ActiveRecord::Type::Value) do
      define_method(:changed_in_place?) do |*|
        raise
      end
    end
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = 'people'
      attribute :foo, test_type_class.new
    end

    model = klass.new(first_name: "Jim")
    assert model.first_name_changed?
  end

  test "attribute_will_change! doesn't try to save non-persistable attributes" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = 'people'
      attribute :non_persisted_attribute, :string
    end

    record = klass.new(first_name: "Sean")
    record.non_persisted_attribute_will_change!

    assert record.non_persisted_attribute_changed?
    assert record.save
  end

  test "mutating and then assigning doesn't remove the change" do
    pirate = Pirate.create!(catchphrase: "arrrr")
    pirate.catchphrase << " matey!"
    pirate.catchphrase = "arrrr matey!"

    assert pirate.catchphrase_changed?(from: "arrrr", to: "arrrr matey!")
  end

  test "getters with side effects are allowed" do
    klass = Class.new(Pirate) do
      def catchphrase
        if super.blank?
          update_attribute(:catchphrase, "arr") # what could possibly go wrong?
        end
        super
      end
    end

    pirate = klass.create!(catchphrase: "lol")
    pirate.update_attribute(:catchphrase, nil)

    assert_equal "arr", pirate.catchphrase
  end

  test "attributes assigned but not selected are dirty" do
    person = Person.select(:id).first
    refute person.changed?

    person.first_name = "Sean"
    assert person.changed?

    person.first_name = nil
    assert person.changed?
  end

  private
    def with_partial_writes(klass, on = true)
      old = klass.partial_writes?
      klass.partial_writes = on
      yield
    ensure
      klass.partial_writes = old
    end

    def check_pirate_after_save_failure(pirate)
      assert pirate.changed?
      assert pirate.parrot_id_changed?
      assert_equal %w(parrot_id), pirate.changed
      assert_nil pirate.parrot_id_was
    end
end
