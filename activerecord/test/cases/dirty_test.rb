# frozen_string_literal: true

require "cases/helper"
require "models/topic"    # For booleans
require "models/pirate"   # For timestamps
require "models/parrot"
require "models/person"   # For optimistic locking
require "models/aircraft"
require "models/numeric_data"
require "models/default"

class DirtyTest < ActiveRecord::TestCase
  include InTimeZone

  # Dummy to force column loads so query counts are clean.
  def setup
    Person.create first_name: "foo"
  end

  def teardown
    Person.delete_by(first_name: "foo")
  end

  def test_attribute_changes
    # New record - no changes.
    pirate = Pirate.new
    assert_equal false, pirate.catchphrase_changed?
    assert_equal false, pirate.non_validated_parrot_id_changed?

    # Change catchphrase.
    pirate.catchphrase = "arrr"
    assert_predicate pirate, :catchphrase_changed?
    assert_nil pirate.catchphrase_was
    assert_equal [nil, "arrr"], pirate.catchphrase_change

    # Saved - no changes.
    pirate.save!
    assert_not_predicate pirate, :catchphrase_changed?
    assert_nil pirate.catchphrase_change

    # Same value - no changes.
    pirate.catchphrase = "arrr"
    assert_not_predicate pirate, :catchphrase_changed?
    assert_nil pirate.catchphrase_change
  end

  def test_time_attributes_changes_with_time_zone
    in_time_zone "Paris" do
      target = Class.new(ActiveRecord::Base)
      target.table_name = "pirates"

      # New record - no changes.
      pirate = target.new
      assert_not_predicate pirate, :created_on_changed?
      assert_nil pirate.created_on_change

      # Saved - no changes.
      pirate.catchphrase = "arrrr, time zone!!"
      pirate.save!
      assert_not_predicate pirate, :created_on_changed?
      assert_nil pirate.created_on_change

      # Change created_on.
      old_created_on = pirate.created_on
      pirate.created_on = Time.now - 1.day
      assert_predicate pirate, :created_on_changed?
      assert_kind_of ActiveSupport::TimeWithZone, pirate.created_on_was
      assert_equal old_created_on, pirate.created_on_was
      pirate.created_on = old_created_on
      assert_not_predicate pirate, :created_on_changed?
    end
  end

  def test_setting_time_attributes_with_time_zone_field_to_itself_should_not_be_marked_as_a_change
    in_time_zone "Paris" do
      target = Class.new(ActiveRecord::Base)
      target.table_name = "pirates"

      pirate = target.create!
      pirate.created_on = pirate.created_on
      assert_not_predicate pirate, :created_on_changed?
    end
  end

  def test_time_attributes_changes_without_time_zone_by_skip
    in_time_zone "Paris" do
      target = Class.new(ActiveRecord::Base)
      target.table_name = "pirates"

      target.skip_time_zone_conversion_for_attributes = [:created_on]

      # New record - no changes.
      pirate = target.new
      assert_not_predicate pirate, :created_on_changed?
      assert_nil pirate.created_on_change

      # Saved - no changes.
      pirate.catchphrase = "arrrr, time zone!!"
      pirate.save!
      assert_not_predicate pirate, :created_on_changed?
      assert_nil pirate.created_on_change

      # Change created_on.
      old_created_on = pirate.created_on
      pirate.created_on = Time.now + 1.day
      assert_predicate pirate, :created_on_changed?
      # kind_of does not work because
      # ActiveSupport::TimeWithZone.name == 'Time'
      assert_instance_of Time, pirate.created_on_was
      assert_equal old_created_on, pirate.created_on_was
    end
  end

  def test_time_attributes_changes_without_time_zone
    with_timezone_config aware_attributes: false do
      target = Class.new(ActiveRecord::Base)
      target.table_name = "pirates"

      # New record - no changes.
      pirate = target.new
      assert_not_predicate pirate, :created_on_changed?
      assert_nil pirate.created_on_change

      # Saved - no changes.
      pirate.catchphrase = "arrrr, time zone!!"
      pirate.save!
      assert_not_predicate pirate, :created_on_changed?
      assert_nil pirate.created_on_change

      # Change created_on.
      old_created_on = pirate.created_on
      pirate.created_on = Time.now + 1.day
      assert_predicate pirate, :created_on_changed?
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
    assert_not_predicate parrot, :title_changed?
    assert_nil parrot.title_change

    parrot.name = "Sam"
    assert_predicate parrot, :title_changed?
    assert_nil parrot.title_was
    assert_equal parrot.name_change, parrot.title_change
  end

  def test_restore_attribute!
    pirate = Pirate.create!(catchphrase: "Yar!")
    pirate.catchphrase = "Ahoy!"

    assert_equal "Ahoy!", pirate.catchphrase
    assert_equal ["Yar!", "Ahoy!"], pirate.catchphrase_change

    pirate.restore_catchphrase!

    assert_nil pirate.catchphrase_change
    assert_equal "Yar!", pirate.catchphrase
    assert_equal Hash.new, pirate.changes
    assert_not_predicate pirate, :catchphrase_changed?
  end

  def test_clear_attribute_change
    pirate = Pirate.create!(catchphrase: "Yar!")
    pirate.catchphrase = "Ahoy!"

    assert_equal "Ahoy!", pirate.catchphrase
    assert_equal ["Yar!", "Ahoy!"], pirate.catchphrase_change

    pirate.clear_catchphrase_change

    assert_nil pirate.catchphrase_change
    assert_equal "Ahoy!", pirate.catchphrase
    assert_equal Hash.new, pirate.changes
    assert_not_predicate pirate, :catchphrase_changed?
  end

  def test_nullable_number_not_marked_as_changed_if_new_value_is_blank
    pirate = Pirate.new

    ["", nil].each do |value|
      pirate.parrot_id = value
      assert_not_predicate pirate, :parrot_id_changed?
      assert_nil pirate.parrot_id_change
    end
  end

  def test_nullable_decimal_not_marked_as_changed_if_new_value_is_blank
    numeric_data = NumericData.new

    ["", nil].each do |value|
      numeric_data.bank_balance = value
      assert_not_predicate numeric_data, :bank_balance_changed?
      assert_nil numeric_data.bank_balance_change
    end
  end

  def test_nullable_float_not_marked_as_changed_if_new_value_is_blank
    numeric_data = NumericData.new

    ["", nil].each do |value|
      numeric_data.temperature = value
      assert_not_predicate numeric_data, :temperature_changed?
      assert_nil numeric_data.temperature_change
    end
  end

  def test_nullable_datetime_not_marked_as_changed_if_new_value_is_blank
    in_time_zone "Edinburgh" do
      target = Class.new(ActiveRecord::Base)
      target.table_name = "topics"

      topic = target.create
      assert_nil topic.written_on

      ["", nil].each do |value|
        topic.written_on = value
        assert_nil topic.written_on
        assert_not_predicate topic, :written_on_changed?
      end
    end
  end

  def test_integer_zero_to_string_zero_not_marked_as_changed
    pirate = Pirate.new
    pirate.parrot_id = 0
    pirate.catchphrase = "arrr"
    assert pirate.save!

    assert_not_predicate pirate, :changed?

    pirate.parrot_id = "0"
    assert_not_predicate pirate, :changed?
  end

  def test_integer_zero_to_integer_zero_not_marked_as_changed
    pirate = Pirate.new
    pirate.parrot_id = 0
    pirate.catchphrase = "arrr"
    assert pirate.save!

    assert_not_predicate pirate, :changed?

    pirate.parrot_id = 0
    assert_not_predicate pirate, :changed?
  end

  def test_float_zero_to_string_zero_not_marked_as_changed
    data = NumericData.new temperature: 0.0
    data.save!

    assert_not_predicate data, :changed?

    data.temperature = "0"
    assert_empty data.changes

    data.temperature = "0.0"
    assert_empty data.changes

    data.temperature = "0.00"
    assert_empty data.changes
  end

  def test_zero_to_blank_marked_as_changed
    pirate = Pirate.new
    pirate.catchphrase = "Yarrrr, me hearties"
    pirate.parrot_id = 1
    pirate.save

    # check the change from 1 to ''
    pirate = Pirate.find_by_catchphrase("Yarrrr, me hearties")
    pirate.parrot_id = ""
    assert_predicate pirate, :parrot_id_changed?
    assert_equal([1, nil], pirate.parrot_id_change)
    pirate.save

    # check the change from nil to 0
    pirate = Pirate.find_by_catchphrase("Yarrrr, me hearties")
    pirate.parrot_id = 0
    assert_predicate pirate, :parrot_id_changed?
    assert_equal([nil, 0], pirate.parrot_id_change)
    pirate.save

    # check the change from 0 to ''
    pirate = Pirate.find_by_catchphrase("Yarrrr, me hearties")
    pirate.parrot_id = ""
    assert_predicate pirate, :parrot_id_changed?
    assert_equal([0, nil], pirate.parrot_id_change)
  end

  def test_object_should_be_changed_if_any_attribute_is_changed
    pirate = Pirate.new
    assert_not_predicate pirate, :changed?
    assert_equal [], pirate.changed
    assert_equal Hash.new, pirate.changes

    pirate.catchphrase = "arrr"
    assert_predicate pirate, :changed?
    assert_nil pirate.catchphrase_was
    assert_equal %w(catchphrase), pirate.changed
    assert_equal({ "catchphrase" => [nil, "arrr"] }, pirate.changes)

    pirate.save
    assert_not_predicate pirate, :changed?
    assert_equal [], pirate.changed
    assert_equal Hash.new, pirate.changes
  end

  def test_attribute_will_change!
    pirate = Pirate.create!(catchphrase: "arr")

    assert_not_predicate pirate, :catchphrase_changed?
    assert pirate.catchphrase_will_change!
    assert_predicate pirate, :catchphrase_changed?
    assert_equal ["arr", "arr"], pirate.catchphrase_change

    pirate.catchphrase << " matey!"
    assert_predicate pirate, :catchphrase_changed?
    assert_equal ["arr", "arr matey!"], pirate.catchphrase_change
  end

  def test_virtual_attribute_will_change
    parrot = Parrot.create!(name: "Ruby")
    parrot.send(:attribute_will_change!, :cancel_save_from_callback)
    assert_predicate parrot, :has_changes_to_save?
  end

  def test_association_assignment_changes_foreign_key
    pirate = Pirate.create!(catchphrase: "jarl")
    pirate.parrot = Parrot.create!(name: "Lorre")
    assert_predicate pirate, :changed?
    assert_equal %w(parrot_id), pirate.changed
  end

  def test_attribute_should_be_compared_with_type_cast
    topic = Topic.new
    assert_predicate topic, :approved?
    assert_not_predicate topic, :approved_changed?

    # Coming from web form.
    params = { topic: { approved: 1 } }
    # In the controller.
    topic.attributes = params[:topic]
    assert_predicate topic, :approved?
    assert_not_predicate topic, :approved_changed?
  end

  def test_string_attribute_should_compare_with_typecast_symbol_after_update
    pirate = Pirate.create!(catchphrase: :foo)
    pirate.update_column :catchphrase, :foo
    pirate.catchphrase
    assert_not_predicate pirate, :catchphrase_changed?
  end

  def test_partial_update
    pirate = Pirate.new(catchphrase: "foo")
    old_updated_on = 1.hour.ago.beginning_of_day

    with_partial_writes Pirate, false do
      assert_queries_count(6) { 2.times { pirate.save! } }
      Pirate.where(id: pirate.id).update_all(updated_on: old_updated_on)
    end

    with_partial_writes Pirate, true do
      assert_no_queries { 2.times { pirate.save! } }
      assert_equal old_updated_on, pirate.reload.updated_on

      assert_queries_count(3) { pirate.catchphrase = "bar"; pirate.save! }
      assert_not_equal old_updated_on, pirate.reload.updated_on
    end
  end

  def test_partial_update_with_optimistic_locking
    person = Person.new(first_name: "foo")

    with_partial_writes Person, false do
      assert_queries_count(6) { 2.times { person.save! } }
      Person.where(id: person.id).update_all(first_name: "baz")
    end

    old_lock_version = person.lock_version + 1

    with_partial_writes Person, true do
      assert_no_queries { 2.times { person.save! } }
      assert_equal old_lock_version, person.reload.lock_version

      assert_queries_count(3) { person.first_name = "bar"; person.save! }
      assert_not_equal old_lock_version, person.reload.lock_version
    end
  end

  def test_changed_attributes_should_be_preserved_if_save_failure
    pirate = Pirate.new
    pirate.parrot_id = 1
    assert_not pirate.save
    check_pirate_after_save_failure(pirate)

    pirate = Pirate.new
    pirate.parrot_id = 1
    assert_raise(ActiveRecord::RecordInvalid) { pirate.save! }
    check_pirate_after_save_failure(pirate)
  end

  def test_reload_should_clear_changed_attributes
    pirate = Pirate.create!(catchphrase: "shiver me timbers")
    pirate.catchphrase = "*hic*"
    assert_predicate pirate, :changed?
    pirate.reload
    assert_not_predicate pirate, :changed?
  end

  def test_dup_objects_should_not_copy_dirty_flag_from_creator
    pirate = Pirate.create!(catchphrase: "shiver me timbers")
    pirate_dup = pirate.dup
    pirate_dup.restore_catchphrase!
    pirate.catchphrase = "I love Rum"
    assert_predicate pirate, :catchphrase_changed?
    assert_not_predicate pirate_dup, :catchphrase_changed?
  end

  def test_reverted_changes_are_not_dirty
    phrase = "shiver me timbers"
    pirate = Pirate.create!(catchphrase: phrase)
    pirate.catchphrase = "*hic*"
    assert_predicate pirate, :changed?
    pirate.catchphrase = phrase
    assert_not_predicate pirate, :changed?
  end

  def test_reverted_changes_are_not_dirty_after_multiple_changes
    phrase = "shiver me timbers"
    pirate = Pirate.create!(catchphrase: phrase)
    10.times do |i|
      pirate.catchphrase = "*hic*" * i
      assert_predicate pirate, :changed?
    end
    assert_predicate pirate, :changed?
    pirate.catchphrase = phrase
    assert_not_predicate pirate, :changed?
  end

  def test_reverted_changes_are_not_dirty_going_from_nil_to_value_and_back
    pirate = Pirate.create!(catchphrase: "Yar!")

    pirate.parrot_id = 1
    assert_predicate pirate, :changed?
    assert_predicate pirate, :parrot_id_changed?
    assert_not_predicate pirate, :catchphrase_changed?

    pirate.parrot_id = nil
    assert_not_predicate pirate, :changed?
    assert_not_predicate pirate, :parrot_id_changed?
    assert_not_predicate pirate, :catchphrase_changed?
  end

  def test_save_should_store_serialized_attributes_even_with_partial_writes
    with_partial_writes(Topic) do
      topic = Topic.create!(content: { "a" => "a" })

      assert_not_predicate topic, :changed?

      topic.content["b"] = "b"

      assert_predicate topic, :changed?

      topic.save!

      assert_not_predicate topic, :changed?
      assert_equal "b", topic.content["b"]

      topic.reload

      assert_equal "b", topic.content["b"]
    end
  end

  def test_save_always_should_update_timestamps_when_serialized_attributes_are_present
    with_partial_writes(Topic) do
      topic = Topic.create!(content: { "a" => "a" })
      topic.save!

      updated_at = topic.updated_at
      travel(1.second) do
        topic.content["hello"] = "world"
        topic.save!
      end

      assert_not_equal updated_at, topic.updated_at
      assert_equal "world", topic.content["hello"]
    end
  end

  def test_save_should_not_save_serialized_attribute_with_partial_writes_if_not_present
    with_partial_writes(Topic) do
      topic = Topic.create!(author_name: "Bill", content: { "a" => "a" })
      topic = Topic.select("id, author_name").find(topic.id)
      topic.update_columns author_name: "John"
      assert_not_nil topic.reload.content
    end
  end

  def test_changes_to_save_should_not_mutate_array_of_hashes
    topic = Topic.new(author_name: "Bill", content: [{ "a" => "a" }])

    topic.changes_to_save

    assert_equal [{ "a" => "a" }], topic.content
  end

  def test_previous_changes
    # original values should be in previous_changes
    pirate = Pirate.new

    assert_equal Hash.new, pirate.previous_changes
    pirate.catchphrase = "arrr"
    pirate.save!

    assert_equal 4, pirate.previous_changes.size
    assert_equal [nil, "arrr"], pirate.previous_changes["catchphrase"]
    assert_nil pirate.catchphrase_previously_was
    assert_equal [nil, pirate.id], pirate.previous_changes["id"]
    assert_nil pirate.previous_changes["updated_on"][0]
    assert_not_nil pirate.previous_changes["updated_on"][1]
    assert_nil pirate.previous_changes["created_on"][0]
    assert_not_nil pirate.previous_changes["created_on"][1]
    assert_not pirate.previous_changes.key?("parrot_id")

    # original values should be in previous_changes
    pirate = Pirate.new

    assert_equal Hash.new, pirate.previous_changes
    pirate.catchphrase = "arrr"
    pirate.save

    assert_equal 4, pirate.previous_changes.size
    assert_equal [nil, "arrr"], pirate.previous_changes["catchphrase"]
    assert_nil pirate.catchphrase_previously_was
    assert_equal [nil, pirate.id], pirate.previous_changes["id"]
    assert_includes pirate.previous_changes, "updated_on"
    assert_includes pirate.previous_changes, "created_on"
    assert_not pirate.previous_changes.key?("parrot_id")

    pirate.catchphrase = "Yar!!"
    pirate.reload
    assert_equal Hash.new, pirate.previous_changes

    pirate = Pirate.find_by_catchphrase("arrr")

    travel(1.second)

    pirate.catchphrase = "Me Maties!"
    pirate.save!

    assert_equal 2, pirate.previous_changes.size
    assert_equal ["arrr", "Me Maties!"], pirate.previous_changes["catchphrase"]
    assert_equal "arrr", pirate.catchphrase_previously_was
    assert_not_nil pirate.previous_changes["updated_on"][0]
    assert_not_nil pirate.previous_changes["updated_on"][1]
    assert_not pirate.previous_changes.key?("parrot_id")
    assert_not pirate.previous_changes.key?("created_on")

    pirate = Pirate.find_by_catchphrase("Me Maties!")

    travel(1.second)

    pirate.catchphrase = "Thar She Blows!"
    pirate.save

    assert_equal 2, pirate.previous_changes.size
    assert_equal ["Me Maties!", "Thar She Blows!"], pirate.previous_changes["catchphrase"]
    assert_equal "Me Maties!", pirate.catchphrase_previously_was
    assert_not_nil pirate.previous_changes["updated_on"][0]
    assert_not_nil pirate.previous_changes["updated_on"][1]
    assert_not pirate.previous_changes.key?("parrot_id")
    assert_not pirate.previous_changes.key?("created_on")

    travel(1.second)

    pirate = Pirate.find_by_catchphrase("Thar She Blows!")
    pirate.update(catchphrase: "Ahoy!")

    assert_equal 2, pirate.previous_changes.size
    assert_equal ["Thar She Blows!", "Ahoy!"], pirate.previous_changes["catchphrase"]
    assert_equal "Thar She Blows!", pirate.catchphrase_previously_was
    assert_not_nil pirate.previous_changes["updated_on"][0]
    assert_not_nil pirate.previous_changes["updated_on"][1]
    assert_not pirate.previous_changes.key?("parrot_id")
    assert_not pirate.previous_changes.key?("created_on")

    travel(1.second)

    pirate = Pirate.find_by_catchphrase("Ahoy!")
    pirate.update_attribute(:catchphrase, "Ninjas suck!")

    assert_equal 2, pirate.previous_changes.size
    assert_equal ["Ahoy!", "Ninjas suck!"], pirate.previous_changes["catchphrase"]
    assert_equal "Ahoy!", pirate.catchphrase_previously_was
    assert_not_nil pirate.previous_changes["updated_on"][0]
    assert_not_nil pirate.previous_changes["updated_on"][1]
    assert_not pirate.previous_changes.key?("parrot_id")
    assert_not pirate.previous_changes.key?("created_on")
  end

  def test_field_named_field
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "pirates"
      attribute :field, :string
    end

    assert_nothing_raised do
      klass.new.attributes
    end
  end

  def test_datetime_attribute_can_be_updated_with_fractional_seconds
    in_time_zone "Paris" do
      target = Class.new(ActiveRecord::Base)
      target.table_name = "topics"

      written_on = Time.utc(2012, 12, 1, 12, 0, 0).in_time_zone("Paris")

      topic = target.create(written_on: written_on)
      topic.written_on += 0.3

      assert_predicate topic, :written_on_changed?, "Fractional second update not detected"
    end
  end

  def test_datetime_attribute_doesnt_change_if_zone_is_modified_in_string
    time_in_paris = Time.utc(2014, 1, 1, 12, 0, 0).in_time_zone("Paris")
    pirate = Pirate.create!(catchphrase: "rrrr", created_on: time_in_paris)

    pirate.created_on = pirate.created_on.in_time_zone("Tokyo").to_s
    assert_not_predicate pirate, :created_on_changed?
  end

  test "partial insert" do
    with_partial_writes Person do
      jon = nil
      assert_no_queries_match(/followers_count/) do
        assert_queries_match(/first_name/) do
          jon = Person.create! first_name: "Jon"
        end
      end

      jon.reload
      assert_equal "Jon", jon.first_name
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

    assert_predicate pirate, :catchphrase_changed?
    expected_changes = {
      "catchphrase" => ["arrrr", "arrrr matey!"]
    }
    assert_equal(expected_changes, pirate.changes)
    assert_equal("arrrr", pirate.catchphrase_was)
    assert pirate.catchphrase_changed?(from: "arrrr")
    assert_not pirate.catchphrase_changed?(from: "anything else")
    assert_includes pirate.changed_attributes, :catchphrase

    pirate.save!
    pirate.reload

    assert_equal "arrrr matey!", pirate.catchphrase
    assert_not_predicate pirate, :changed?
  end

  test "in place mutation for binary" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = :binaries
      serialize :data
    end

    binary = klass.create!(data: "\\\\foo")

    assert_not_predicate binary, :changed?

    binary.data = binary.data.dup

    assert_not_predicate binary, :changed?

    binary = klass.last

    assert_not_predicate binary, :changed?

    binary.data << "bar"

    assert_predicate binary, :changed?
  end

  test "changes is correct for subclass" do
    foo = Class.new(Pirate) do
      def catchphrase
        super.upcase
      end
    end

    pirate = foo.create!(catchphrase: "arrrr")

    new_catchphrase = "arrrr matey!"

    pirate.catchphrase = new_catchphrase
    assert_predicate pirate, :catchphrase_changed?

    expected_changes = {
      "catchphrase" => ["arrrr", new_catchphrase]
    }

    assert_equal new_catchphrase.upcase, pirate.catchphrase
    assert_equal expected_changes, pirate.changes
  end

  test "changes is correct if override attribute reader" do
    pirate = Pirate.create!(catchphrase: "arrrr")
    def pirate.catchphrase
      super.upcase
    end

    new_catchphrase = "arrrr matey!"

    pirate.catchphrase = new_catchphrase
    assert_predicate pirate, :catchphrase_changed?

    expected_changes = {
      "catchphrase" => ["arrrr", new_catchphrase]
    }

    assert_equal new_catchphrase.upcase, pirate.catchphrase
    assert_equal expected_changes, pirate.changes
  end

  test "attribute_changed? doesn't compute in-place changes for unrelated attributes" do
    test_type_class = Class.new(ActiveRecord::Type::Value) do
      define_method(:changed_in_place?) do |*|
        raise
      end
    end
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "people"
      attribute :foo, test_type_class.new
    end

    model = klass.new(first_name: "Jim")
    assert_predicate model, :first_name_changed?
  end

  test "attribute_will_change! doesn't try to save non-persistable attributes" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "people"
      attribute :non_persisted_attribute, :string
    end

    record = klass.new(first_name: "Sean")
    record.non_persisted_attribute_will_change!

    assert_predicate record, :non_persisted_attribute_changed?
    assert record.save
  end

  test "virtual attributes are not written with partial_writes off" do
    with_partial_writes(ActiveRecord::Base, false) do
      klass = Class.new(ActiveRecord::Base) do
        self.table_name = "people"
        attribute :non_persisted_attribute, :string
      end

      record = klass.new(first_name: "Sean")
      record.non_persisted_attribute_will_change!

      assert record.save

      record.non_persisted_attribute_will_change!

      assert record.save
    end
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
    assert_not_predicate person, :changed?

    person.first_name = "Sean"
    assert_predicate person, :changed?

    person.first_name = nil
    assert_predicate person, :changed?
  end

  test "attributes not selected are still missing after save" do
    person = Person.select(:id).first
    assert_raises(ActiveModel::MissingAttributeError) { person.first_name }
    assert person.save # calls forget_attribute_assignments
    assert_raises(ActiveModel::MissingAttributeError) { person.first_name }
  end

  test "saved_change_to_attribute? returns whether a change occurred in the last save" do
    person = Person.create!(first_name: "Sean")

    assert_predicate person, :saved_change_to_first_name?
    assert_not_predicate person, :saved_change_to_gender?
    assert person.saved_change_to_first_name?(from: nil, to: "Sean")
    assert person.saved_change_to_first_name?(from: nil)
    assert person.saved_change_to_first_name?(to: "Sean")
    assert_not person.saved_change_to_first_name?(from: "Jim", to: "Sean")
    assert_not person.saved_change_to_first_name?(from: "Jim")
    assert_not person.saved_change_to_first_name?(to: "Jim")
  end

  test "saved_change_to_attribute returns the change that occurred in the last save" do
    person = Person.create!(first_name: "Sean", gender: "M")

    assert_equal [nil, "Sean"], person.saved_change_to_first_name
    assert_equal [nil, "M"], person.saved_change_to_gender

    person.update(first_name: "Jim")

    assert_equal ["Sean", "Jim"], person.saved_change_to_first_name
    assert_nil person.saved_change_to_gender
  end

  test "attribute_before_last_save returns the original value before saving" do
    person = Person.create!(first_name: "Sean", gender: "M")

    assert_nil person.first_name_before_last_save
    assert_nil person.gender_before_last_save

    person.first_name = "Jim"

    assert_nil person.first_name_before_last_save
    assert_nil person.gender_before_last_save

    person.save

    assert_equal "Sean", person.first_name_before_last_save
    assert_equal "M", person.gender_before_last_save
  end

  test "saved_changes? returns whether the last call to save changed anything" do
    person = Person.create!(first_name: "Sean")

    assert_predicate person, :saved_changes?

    person.save

    assert_not_predicate person, :saved_changes?
  end

  test "saved_changes returns a hash of all the changes that occurred" do
    person = Person.create!(first_name: "Sean", gender: "M")

    assert_equal [nil, "Sean"], person.saved_changes[:first_name]
    assert_equal [nil, "M"], person.saved_changes[:gender]
    assert_equal %w(id first_name gender created_at updated_at).sort, person.saved_changes.keys.sort

    travel(1.second) do
      person.update(first_name: "Jim")
    end

    assert_equal ["Sean", "Jim"], person.saved_changes[:first_name]
    assert_equal %w(first_name lock_version updated_at).sort, person.saved_changes.keys.sort
  end

  test "changed? in after callbacks returns false" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "people"

      after_save do
        raise "changed? should be false" if changed?
        raise "has_changes_to_save? should be false" if has_changes_to_save?
        raise "saved_changes? should be true" unless saved_changes?
        raise "id_in_database should not be nil" if id_in_database.nil?
      end
    end

    person = klass.create!(first_name: "Sean")
    assert_not_predicate person, :changed?
  end

  test "changed? in around callbacks after yield returns false" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "people"

      around_create :check_around

      def check_around
        yield
        raise "changed? should be false" if changed?
        raise "has_changes_to_save? should be false" if has_changes_to_save?
        raise "saved_changes? should be true" unless saved_changes?
        raise "id_in_database should not be nil" if id_in_database.nil?
      end
    end

    person = klass.create!(first_name: "Sean")
    assert_not_predicate person, :changed?
  end

  test "partial insert off with unchanged default function attribute" do
    with_partial_writes Aircraft, false do
      aircraft = Aircraft.new(name: "Boeing")
      assert_equal "Boeing", aircraft.name

      aircraft.save!
      aircraft.reload

      assert_equal "Boeing", aircraft.name
      assert_in_delta Time.now, aircraft.manufactured_at, 1.1
    end
  end

  test "partial insert off with changed default function attribute" do
    with_partial_writes Aircraft, false do
      manufactured_at = 1.years.ago
      aircraft = Aircraft.new(name: "Boeing2", manufactured_at: manufactured_at)

      assert_equal "Boeing2", aircraft.name
      assert_equal manufactured_at.to_i, aircraft.manufactured_at.to_i

      aircraft.save!
      aircraft.reload

      assert_equal "Boeing2", aircraft.name
      assert_equal manufactured_at.utc.strftime("%Y-%m-%d %H:%M:%S"), aircraft.manufactured_at.strftime("%Y-%m-%d %H:%M:%S")
    end
  end

  if current_adapter?(:PostgreSQLAdapter) && supports_identity_columns?
    test "partial insert off with changed composite identity primary key attribute" do
      klass = Class.new(ActiveRecord::Base) do
        self.table_name = "cpk_postgresql_identity_table"
      end

      with_partial_writes(klass, false) do
        record = klass.create!(another_id: 10)
        assert_equal 10, record.another_id
        assert_not_nil record.id
      end
    end
  end

  test "attribute_changed? properly type casts enum values" do
    parrot = LiveParrot.create!(name: "Scipio", breed: :african)

    parrot.breed = :australian

    assert parrot.breed_changed?(from: "african", to: "australian")
    assert parrot.breed_changed?(from: :african, to: :australian)
    assert parrot.breed_changed?(from: 0, to: 1)
  end

  def test_virtual_column_loaded_change_on_update
    record_with_defaults = Default.create(random_number: 105)
    record_with_defaults.update!(random_number: 140)

    assert_equal [1050, 1400], record_with_defaults.previous_changes[:virtual_stored_number]
  end if current_adapter?(:PostgreSQLAdapter) && supports_virtual_columns?

  private
    def with_partial_writes(klass, on = true)
      old_inserts = klass.partial_inserts?
      old_updates = klass.partial_updates?
      klass.partial_inserts = on
      klass.partial_updates = on
      yield
    ensure
      klass.partial_inserts = old_inserts
      klass.partial_updates = old_updates
    end

    def check_pirate_after_save_failure(pirate)
      assert_predicate pirate, :changed?
      assert_predicate pirate, :parrot_id_changed?
      assert_equal %w(parrot_id), pirate.changed
      assert_nil pirate.parrot_id_was
    end
end

class TransactionChangesDirtyTest < ActiveRecord::TestCase
  # These tests require real transaction boundaries so that committed! is
  # called between independent operations.  Transactional test wrapping
  # encloses the entire test in a single joinable transaction, which means
  # committed! is never called and transaction_changes accumulates from the
  # very first save — correct behaviour, but incompatible with assertions
  # that assume each save/transaction block is independent.
  self.use_transactional_tests = false

  class ShardedBase < ActiveRecord::Base
    self.abstract_class = true
  end

  class ShardedPerson < ShardedBase
    self.table_name = :transaction_change_people

    attr_accessor :transaction_changes_log

    after_commit do
      self.transaction_changes_log = transaction_changes.dup
    end
  end

  setup do
    # Re-establish shard connections in setup because the shared connection
    # pool setup performed by other test cases in a full suite run overwrites
    # connections established at file load time. See shard_keys_test.rb.
    ShardedBase.connects_to shards: {
      default: { writing: :arunit },
      secondary: { writing: :arunit2 },
    }

    Person.delete_all
    Parrot.delete_all
    Topic.delete_all
  end

  test "transaction_change_to_attribute? returns whether a change occurred in the transaction" do
    person = Person.create!(first_name: "Sean")

    assert_predicate person, :transaction_change_to_first_name?
    assert_not_predicate person, :transaction_change_to_gender?
    assert person.transaction_change_to_first_name?(from: nil, to: "Sean")
    assert person.transaction_change_to_first_name?(from: nil)
    assert person.transaction_change_to_first_name?(to: "Sean")
    assert_not person.transaction_change_to_first_name?(from: "Jim", to: "Sean")
    assert_not person.transaction_change_to_first_name?(from: "Jim")
    assert_not person.transaction_change_to_first_name?(to: "Jim")
  end

  test "transaction_change_to_attribute? properly type casts enum values" do
    parrot = LiveParrot.create!(name: "Scipio", breed: :african)

    parrot.update!(breed: :australian)

    assert parrot.transaction_change_to_breed?(from: "african", to: "australian")
    assert parrot.transaction_change_to_breed?(from: :african, to: :australian)
    assert parrot.transaction_change_to_breed?(from: 0, to: 1)
  end

  test "transaction_change_to_attribute returns the change that occurred in the transaction" do
    person = Person.create!(first_name: "Sean", gender: "M")

    assert_equal [nil, "Sean"], person.transaction_change_to_first_name
    assert_equal [nil, "M"], person.transaction_change_to_gender

    person.update(first_name: "Jim")

    assert_equal ["Sean", "Jim"], person.transaction_change_to_first_name
    assert_nil person.transaction_change_to_gender
  end

  test "attribute_before_transaction returns the original value before the transaction" do
    person = Person.create!(first_name: "Sean", gender: "M")

    assert_nil person.first_name_before_transaction
    assert_nil person.gender_before_transaction

    person.update(first_name: "Jim")

    assert_equal "Sean", person.first_name_before_transaction
    assert_equal "M", person.gender_before_transaction
  end

  test "attribute_before_transaction returns current value for unchanged attribute" do
    person = Person.create!(first_name: "Sean", gender: "M")

    person.update!(first_name: "Jim")

    # gender wasn't changed, so before_transaction returns the current value
    assert_equal "M", person.gender_before_transaction
  end

  test "transaction_changes? returns whether the transaction changed anything" do
    person = Person.create!(first_name: "Sean")

    assert_predicate person, :transaction_changes?

    person.save

    assert_not_predicate person, :transaction_changes?
  end

  test "transaction_changes returns a hash of all the changes that occurred in the transaction" do
    person = Person.create!(first_name: "Sean", gender: "M")

    assert_equal [nil, "Sean"], person.transaction_changes[:first_name]
    assert_equal [nil, "M"], person.transaction_changes[:gender]
    assert_equal %w(id first_name gender created_at updated_at).sort, person.transaction_changes.keys.sort

    travel(1.second) do
      person.update(first_name: "Jim")
    end

    assert_equal ["Sean", "Jim"], person.transaction_changes[:first_name]
    assert_equal %w(first_name lock_version updated_at).sort, person.transaction_changes.keys.sort
  end

  test "partial updates do not change the net transaction diff" do
    transaction_changes = [true, false].map do |partial_updates|
      klass = Class.new(ActiveRecord::Base) do
        self.table_name = :topics
        self.partial_updates = partial_updates
        self.record_timestamps = false
      end

      topic = klass.create!(title: "Original", author_name: "Alice", written_on: Date.today).reload
      topic.update!(title: "Updated")
      topic.transaction_changes
    end

    expected = { "title" => ["Original", "Updated"] }.with_indifferent_access
    assert_equal expected, transaction_changes.first
    assert_equal transaction_changes.first, transaction_changes.last
  end

  test "pending readonly and virtual attributes are excluded after a successful save" do
    transaction_changes_before_save = nil
    previous_raise_on_readonly = ActiveRecord.raise_on_assign_to_attr_readonly
    begin
      ActiveRecord.raise_on_assign_to_attr_readonly = false
      klass = Class.new(ActiveRecord::Base) do
        self.table_name = :topics
        attribute :virtual_candidate, :string
        attr_readonly :author_name

        before_save do
          transaction_changes_before_save = transaction_changes.dup
        end
      end
    ensure
      ActiveRecord.raise_on_assign_to_attr_readonly = previous_raise_on_readonly
    end

    topic = klass.create!(title: "Original", author_name: "Alice", written_on: Date.today).reload
    transaction_changes_before_save = nil
    topic.assign_attributes(title: "Updated", author_name: "Bob", virtual_candidate: "pending")
    topic.save!

    assert_equal ["Alice", "Bob"], transaction_changes_before_save["author_name"]
    assert_equal [nil, "pending"], transaction_changes_before_save["virtual_candidate"]
    assert_equal ["Original", "Updated"], topic.transaction_changes["title"]
    assert_not topic.transaction_changes.key?("author_name")
    assert_not topic.transaction_changes.key?("virtual_candidate")
  end

  test "in-place and forced transaction changes require a different final value" do
    changed_in_place = Person.create!(first_name: "Sean").reload
    changed_in_place.first_name << " Jr"
    changed_in_place.save!
    assert_equal ["Sean", "Sean Jr"], changed_in_place.transaction_changes["first_name"]

    restored_in_place = Person.create!(first_name: "Sean").reload
    Person.transaction do
      restored_in_place.first_name.replace("Jim")
      restored_in_place.save!
      restored_in_place.first_name.replace("Sean")
      restored_in_place.save!
    end
    assert_not restored_in_place.transaction_changes.key?("first_name")

    forced_same = Person.create!(first_name: "Sean").reload
    forced_same.first_name_will_change!
    forced_same.save!
    assert_not forced_same.transaction_changes.key?("first_name")

    forced_different = Person.create!(first_name: "Sean").reload
    forced_different.first_name_will_change!
    forced_different.first_name = "Jim"
    forced_different.save!
    assert_equal ["Sean", "Jim"], forced_different.transaction_changes["first_name"]
  end

  test "transaction_changes includes touch timestamps and optimistic lock writes" do
    person = Person.create!(first_name: "Sean").reload

    travel 1.second do
      person.touch
    end

    assert_equal [0, 1], person.transaction_changes["lock_version"]
    assert person.transaction_changes.key?("updated_at")
  end

  test "transaction_changes includes a deferred touch and optimistic lock write" do
    klass = deferred_touch_person_class
    person = klass.create!(first_name: "Sean").reload
    original_updated_at = person.updated_at

    travel 1.second do
      klass.transaction do
        person.touch_later
      end
    end

    assert_equal [original_updated_at, person.updated_at], person.transaction_changes_log["updated_at"]
    assert_equal [0, 1], person.transaction_changes_log["lock_version"]
    assert_empty person.saved_changes
    assert_nil person.instance_variable_get(:@_transaction_written_attribute_names)
    assert_nil person.instance_variable_get(:@_deferred_touch_original_attributes)
    assert_equal person.transaction_changes_log, person.transaction_changes
    assert_same person.transaction_changes, person.transaction_changes
  end

  test "transaction_changes keeps the database original when a deferred touch precedes an update" do
    klass = deferred_touch_person_class
    person = klass.create!(first_name: "Sean").reload
    original_updated_at = person.updated_at
    deferred_time = (original_updated_at + 1.hour).change(usec: 0)

    travel_to(deferred_time) do
      klass.transaction do
        person.touch_later
        person.update!(first_name: "Jim")
      end
    end

    assert_equal ["Jim", deferred_time, 2], klass.where(id: person.id).pick(:first_name, :updated_at, :lock_version)
    assert_equal ["Sean", "Jim"], person.transaction_changes_log["first_name"]
    assert_equal [original_updated_at, deferred_time], person.transaction_changes_log["updated_at"]
    assert_equal [0, 2], person.transaction_changes_log["lock_version"]
  end

  test "transaction_changes keeps the database original when an immediate touch flushes a deferred touch" do
    klass = deferred_touch_person_class
    person = klass.create!(first_name: "Sean").reload
    original_updated_at = person.updated_at
    deferred_time = (original_updated_at + 1.hour).change(usec: 0)
    immediate_time = (original_updated_at + 2.hours).change(usec: 0)

    klass.transaction do
      travel_to(deferred_time) { person.touch_later }
      person.touch(time: immediate_time)
    end

    assert_equal [immediate_time, 1], klass.where(id: person.id).pick(:updated_at, :lock_version)
    assert_equal [original_updated_at, immediate_time], person.transaction_changes_log["updated_at"]
    assert_equal [0, 1], person.transaction_changes_log["lock_version"]
  end

  test "transaction_changes folds repeated deferred touches from the earliest database values" do
    klass = deferred_touch_person_class
    person = klass.create!(first_name: "Sean").reload
    original_created_at = person.created_at
    original_updated_at = person.updated_at
    first_time = (original_updated_at + 1.hour).change(usec: 0)
    last_time = (original_updated_at + 2.hours).change(usec: 0)
    saved_changes_after_update = nil

    klass.transaction do
      travel_to(first_time) { person.touch_later }
      travel_to(last_time) do
        person.touch_later(:created_at)
        person.update!(first_name: "Jim")
        saved_changes_after_update = person.saved_changes.deep_dup
      end
    end

    assert_equal ["Jim", last_time, last_time, 2], klass.where(id: person.id).pick(:first_name, :created_at, :updated_at, :lock_version)
    assert_equal ["Sean", "Jim"], person.transaction_changes_log["first_name"]
    assert_equal [original_created_at, last_time], person.transaction_changes_log["created_at"]
    assert_equal [original_updated_at, last_time], person.transaction_changes_log["updated_at"]
    assert_equal [0, 2], person.transaction_changes_log["lock_version"]
    assert_equal saved_changes_after_update, person.saved_changes
  end

  test "an aborted immediate touch after touch_later does not leak its baseline into a later transaction" do
    klass = deferred_touch_person_class
    person = klass.create!(first_name: "Sean").reload
    person.transaction_changes_log = nil
    original_updated_at = person.updated_at
    deferred_time = (original_updated_at + 1.hour).change(usec: 0)
    immediate_time = (original_updated_at + 2.hours).change(usec: 0)

    touch_result = nil
    row_after_abort = nil
    state_after_abort = nil

    klass.transaction do
      travel_to(deferred_time) { person.touch_later }
      person.abort_touch = true
      touch_result = person.touch(time: immediate_time)
      person.abort_touch = false
      row_after_abort = klass.where(id: person.id).pick(:updated_at, :lock_version)
      state_after_abort = touch_later_internal_state(person)
    end

    assert_nil person.transaction_changes_log
    assert_empty person.transaction_changes
    assert_equal [original_updated_at, 0], klass.where(id: person.id).pick(:updated_at, :lock_version)

    advanced_time = (original_updated_at + 3.hours).change(usec: 0)
    final_time = (original_updated_at + 4.hours).change(usec: 0)
    klass.find(person.id).touch(time: advanced_time)

    person.reload
    person.touch(time: final_time)

    # The successful touch must report the externally advanced database
    # values as originals, not the pre-abort baseline (original/0).
    assert_equal [final_time, 2], klass.where(id: person.id).pick(:updated_at, :lock_version)
    assert_equal [advanced_time, final_time], person.transaction_changes["updated_at"]
    assert_equal [1, 2], person.transaction_changes["lock_version"]
    assert_equal person.transaction_changes, person.transaction_changes_log

    # The halted touch consumed the deferred names without reaching
    # `_touch_row`, so no SQL ran and no baseline may have survived them.
    assert_equal false, touch_result
    assert_equal [original_updated_at, 0], row_after_abort
    assert_equal({ defer_touch_attrs: nil, deferred_touch_original_attributes: nil, transaction_written_attribute_names: nil }, state_after_abort)
  end

  test "an aborted immediate touch after touch_later cancels the deferred baseline under nested transactions" do
    nested_transaction_classes.each do |parent_state, expected_transaction_class|
      klass = deferred_touch_person_class
      person = klass.create!(first_name: "Sean").reload
      person.transaction_changes_log = nil
      original_updated_at = person.updated_at
      deferred_time = (original_updated_at + 1.hour).change(usec: 0)
      immediate_time = (original_updated_at + 2.hours).change(usec: 0)
      nested_transaction_class = nil
      live_changes_after_child = nil
      touch_result = nil

      klass.transaction do
        klass.create!(first_name: "Dirty parent") if parent_state == :dirty_parent

        klass.transaction(requires_new: true) do
          nested_transaction_class = klass.lease_connection.current_transaction.class
          travel_to(deferred_time) { person.touch_later }
          person.abort_touch = true
          touch_result = person.touch(time: immediate_time)
          person.abort_touch = false
        end

        live_changes_after_child = person.transaction_changes.dup
      end

      assert_equal expected_transaction_class, nested_transaction_class
      assert_empty live_changes_after_child
      assert_nil person.transaction_changes_log
      assert_empty person.transaction_changes
      assert_equal [original_updated_at, 0], klass.where(id: person.id).pick(:updated_at, :lock_version)
      assert_nil person.instance_variable_get(:@_start_transaction_state)

      advanced_time = (original_updated_at + 3.hours).change(usec: 0)
      final_time = (original_updated_at + 4.hours).change(usec: 0)
      klass.find(person.id).touch(time: advanced_time)

      person.reload
      person.touch(time: final_time)

      assert_equal [final_time, 2], klass.where(id: person.id).pick(:updated_at, :lock_version)
      assert_equal [advanced_time, final_time], person.transaction_changes["updated_at"]
      assert_equal [1, 2], person.transaction_changes["lock_version"]
      assert_equal person.transaction_changes, person.transaction_changes_log
      assert_same person.transaction_changes, person.transaction_changes
      assert_equal false, touch_result
      assert_equal({ defer_touch_attrs: nil, deferred_touch_original_attributes: nil, transaction_written_attribute_names: nil }, touch_later_internal_state(person))
    end
  end

  test "a raised touch callback keeps the deferred names pending and reload discards the stale baseline" do
    klass = deferred_touch_person_class
    person = klass.create!(first_name: "Sean").reload
    original_updated_at = person.updated_at
    deferred_time = (original_updated_at + 1.hour).change(usec: 0)
    immediate_time = (original_updated_at + 2.hours).change(usec: 0)

    person.raise_touch = true
    error = assert_raises(RuntimeError) do
      klass.transaction do
        travel_to(deferred_time) { person.touch_later }
        person.touch(time: immediate_time)
      end
    end
    assert_equal "touch callback failure", error.message
    person.raise_touch = false

    # A raised (rather than halted) touch keeps the deferred names pending so
    # the touch can be retried; the baseline stays owned by those names.
    assert_equal [original_updated_at, 0], klass.where(id: person.id).pick(:updated_at, :lock_version)
    assert_predicate person.instance_variable_get(:@_defer_touch_attrs), :present?
    assert_includes person.instance_variable_get(:@_deferred_touch_original_attributes), "updated_at"
    assert_nil person.instance_variable_get(:@_transaction_written_attribute_names)

    advanced_time = (original_updated_at + 3.hours).change(usec: 0)
    final_time = (original_updated_at + 4.hours).change(usec: 0)
    klass.find(person.id).touch(time: advanced_time)

    # Reload replaces the attributes with fresh database state, so the stale
    # pre-raise baseline must not survive into the next transaction.
    person.reload
    baseline_after_reload = person.instance_variable_get(:@_deferred_touch_original_attributes)

    # The explicit transaction commits after the merged deferred names are
    # consumed, so `before_committed!` does not flush a second touch.
    klass.transaction { person.touch(time: final_time) }

    # The retried touch must report the externally advanced database values
    # as originals, not the pre-raise baseline (original/0).
    assert_equal [final_time, 2], klass.where(id: person.id).pick(:updated_at, :lock_version)
    assert_equal [advanced_time, final_time], person.transaction_changes["updated_at"]
    assert_equal [1, 2], person.transaction_changes["lock_version"]
    assert_nil baseline_after_reload
    assert_equal({ defer_touch_attrs: nil, deferred_touch_original_attributes: nil, transaction_written_attribute_names: nil }, touch_later_internal_state(person))
  end

  test "an exception before update names are captured leaves no transient state" do
    raise_before_update = false
    extension = Module.new do
      define_method(:_update_row) do |attribute_names, attempted_action = "update"|
        raise "before captured #{attempted_action}" if raise_before_update
        super(attribute_names, attempted_action)
      end
    end
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = :people
      self.lock_optimistically = false
      prepend extension
    end
    person = klass.create!(first_name: "Sean").reload
    original_updated_at = person.updated_at

    raise_before_update = true
    error = assert_raises(RuntimeError) { person.update!(first_name: "Aborted") }
    assert_equal "before captured update", error.message
    assert_nil person.instance_variable_get(:@_transaction_written_attribute_names)

    error = assert_raises(RuntimeError) { travel(1.second) { person.touch } }
    assert_equal "before captured touch", error.message
    assert_nil person.instance_variable_get(:@_transaction_written_attribute_names)
    assert_equal ["Sean", original_updated_at], klass.where(id: person.id).pick(:first_name, :updated_at)

    raise_before_update = false
    person.update!(first_name: "Recovered")

    assert_equal ["Sean", "Recovered"], person.transaction_changes["first_name"]
    assert_equal "Recovered", klass.where(id: person.id).pick(:first_name)
  end

  test "compatible persistence prepends that alter or forward name lists preserve finalized transaction writes" do
    calls = []
    extension = Module.new do
      define_method(:_create_record) do
        calls << :create
        super()
      end

      define_method(:_update_record) do
        calls << :update
        super()
      end

      # Alter the explicit touch name list before forwarding, the way
      # optimistic locking alters `_update_row`'s list below this seam.
      define_method(:_touch_row) do |attribute_names, time|
        calls << :touch
        super(attribute_names | ["created_at"], time)
      end

      define_method(:_update_row) do |attribute_names, attempted_action = "update"|
        if attempted_action == "update"
          _write_attribute("comments", "extension write")
          attribute_names |= ["comments"]
        end
        super(attribute_names, attempted_action)
      end
    end
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = :people
      prepend extension
    end

    person = klass.create!(first_name: "Sean").reload
    assert_equal [:create], calls
    calls.clear
    original_created_at = person.created_at
    original_updated_at = person.updated_at
    touch_time = (original_updated_at + 1.hour).change(usec: 0)

    klass.transaction do
      person.update!(first_name: "Jim")
      person.touch(time: touch_time)
    end

    assert_equal [:update, :touch], calls
    assert_equal ["Jim", "extension write", touch_time, touch_time, 2],
      klass.where(id: person.id).pick(:first_name, :comments, :created_at, :updated_at, :lock_version)
    assert_equal ["Sean", "Jim"], person.transaction_changes["first_name"]
    assert_equal [nil, "extension write"], person.transaction_changes["comments"]
    assert_equal [original_created_at, touch_time], person.transaction_changes["created_at"]
    assert_equal [original_updated_at, touch_time], person.transaction_changes["updated_at"]
    assert_equal [0, 2], person.transaction_changes["lock_version"]
    assert_nil person.instance_variable_get(:@_transaction_written_attribute_names)
  end

  test "transaction changes remain isolated across shards" do
    ShardedBase.connected_to(shard: :default) do
      ShardedBase.lease_connection.create_table(:transaction_change_people, force: true) do |t|
        t.string :first_name
        t.timestamps
      end
    end
    ShardedBase.connected_to(shard: :secondary) do
      ShardedBase.lease_connection.create_table(:transaction_change_people, force: true) do |t|
        t.string :first_name
        t.timestamps
      end
    end

    primary_person = ShardedBase.connected_to(shard: :default) do
      ShardedPerson.create!(first_name: "Primary").reload
    end
    secondary_person = ShardedBase.connected_to(shard: :secondary) do
      ShardedPerson.create!(first_name: "Secondary").reload
    end

    ShardedBase.connected_to(shard: :default) do
      ShardedPerson.transaction do
        primary_person.update!(first_name: "Primary final")
        ShardedBase.connected_to(shard: :secondary) do
          ShardedPerson.transaction do
            secondary_person.update!(first_name: "Secondary final")
          end
        end
      end
    end

    assert_equal ["Primary", "Primary final"], primary_person.transaction_changes["first_name"]
    assert_equal ["Secondary", "Secondary final"], secondary_person.transaction_changes["first_name"]
    assert_equal ["Primary", "Primary final"], primary_person.transaction_changes_log["first_name"]
    assert_equal ["Secondary", "Secondary final"], secondary_person.transaction_changes_log["first_name"]
    assert_not_includes primary_person.transaction_changes.values.flatten, "Secondary final"
    assert_not_includes secondary_person.transaction_changes.values.flatten, "Primary final"

    ShardedBase.connected_to(shard: :default) do
      assert_equal "Primary final", ShardedPerson.where(id: primary_person.id).pick(:first_name)
    end
    ShardedBase.connected_to(shard: :secondary) do
      assert_equal "Secondary final", ShardedPerson.where(id: secondary_person.id).pick(:first_name)
    end

    [primary_person, secondary_person].each do |record|
      assert_nil record.instance_variable_get(:@_transaction_written_attribute_names)
      assert_nil record.instance_variable_get(:@_start_transaction_state)
    end
  ensure
    [:default, :secondary].each do |shard|
      ShardedBase.connected_to(shard: shard) do
        ShardedBase.lease_connection.drop_table(:transaction_change_people, if_exists: true)
      end
    end
  end

  test "a stale update does not leak captured write names into a later save" do
    current = Person.create!(first_name: "Sean")
    stale = Person.find(current.id)
    current.update!(first_name: "Jim")

    assert_raises(ActiveRecord::StaleObjectError) { stale.update!(gender: "F") }
    assert_nil stale.instance_variable_get(:@_transaction_written_attribute_names)

    stale.reload
    stale.update!(comments: "saved")

    assert_equal [nil, "saved"], stale.transaction_changes["comments"]
    assert_not stale.transaction_changes.key?("gender")
  end

  test "an exception after update names are captured does not leak them" do
    raise_after_update = false
    extension = Module.new do
      define_method(:_update_row) do |attribute_names, attempted_action = "update"|
        affected_rows = super(attribute_names, attempted_action)
        raise "after captured update" if raise_after_update
        affected_rows
      end
    end
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = :people
      self.lock_optimistically = false
      prepend extension
    end
    person = klass.create!(first_name: "Sean").reload
    raise_after_update = true

    error = assert_raises(RuntimeError) { person.update!(first_name: "Aborted") }
    assert_equal "after captured update", error.message
    assert_nil person.instance_variable_get(:@_transaction_written_attribute_names)
    assert_equal "Sean", klass.where(id: person.id).pick(:first_name)

    raise_after_update = false
    person.assign_attributes(first_name: "Sean", gender: "M")
    person.save!

    assert_equal [nil, "M"], person.transaction_changes["gender"]
    assert_not person.transaction_changes.key?("first_name")
    assert_equal ["Sean", "M"], klass.where(id: person.id).pick(:first_name, :gender)
  end

  test "an exception after touch names are captured clears transient state" do
    raise_after_update = false
    extension = Module.new do
      define_method(:_update_row) do |attribute_names, attempted_action = "update"|
        affected_rows = super(attribute_names, attempted_action)
        raise "after captured touch" if raise_after_update
        affected_rows
      end
    end
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = :people
      self.lock_optimistically = false
      prepend extension
    end
    person = klass.create!(first_name: "Sean").reload
    original_updated_at = person.updated_at
    raise_after_update = true

    error = assert_raises(RuntimeError) { travel(1.second) { person.touch } }
    assert_equal "after captured touch", error.message
    assert_nil person.instance_variable_get(:@_transaction_written_attribute_names)
    assert_equal original_updated_at, klass.where(id: person.id).pick(:updated_at)
  end

  test "transaction_changes tracks cumulative changes across multiple saves in a transaction" do
    person = Person.create!(first_name: "Sean")

    Person.transaction do
      person.update!(first_name: "Intermediate")
      person.update!(first_name: "Jim")
    end

    # transaction_changes spans the full transaction: Sean -> Jim
    assert_equal ["Sean", "Jim"], person.transaction_change_to_first_name
    assert person.transaction_change_to_first_name?(from: "Sean", to: "Jim")
  end

  test "transaction_changes is empty when attribute is changed back to original value" do
    person = Person.create!(first_name: "Sean")

    Person.transaction do
      person.update!(first_name: "Jim")
      person.update!(first_name: "Sean")
    end

    assert_not person.transaction_change_to_first_name?
    assert_nil person.transaction_change_to_first_name
  end

  test "transaction_changes detects change when a later save modifies a different attribute in the same transaction" do
    person = Person.create!(first_name: "Sean", gender: "M")

    Person.transaction do
      person.update!(first_name: "Jim")
      person.update!(gender: "F")
    end

    assert person.transaction_change_to_first_name?
    assert person.transaction_change_to_gender?
    assert_equal ["Sean", "Jim"], person.transaction_change_to_first_name
    assert_equal ["M", "F"], person.transaction_change_to_gender
  end

  test "transaction_changes is cleared on reload" do
    person = Person.create!(first_name: "Sean")

    assert_predicate person, :transaction_changes?

    person.reload

    assert_not_predicate person, :transaction_changes?
    assert_empty person.transaction_changes
    assert_nil person.first_name_before_transaction
  end

  test "destroy with no prior attribute changes returns empty transaction_changes" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = :topics
    end

    record = klass.create!(title: "To Be Destroyed", written_on: Date.today)
    record.reload # clear transaction_changes from the create

    record.destroy

    assert_empty record.transaction_changes,
      "transaction_changes should be empty after destroy with no prior attribute changes"
    assert_not record.transaction_changes?
  end

  test "attribute_before_transaction is stable across multiple saves in a transaction" do
    person = Person.create!(first_name: "Sean")

    Person.transaction do
      person.update!(first_name: "Intermediate")

      assert_equal "Sean", person.first_name_before_transaction

      person.update!(first_name: "Final")

      assert_equal "Sean", person.first_name_before_transaction
    end

    assert_equal "Sean", person.first_name_before_transaction
  end

  test "transaction_changes includes prior attribute changes after destroy in same transaction" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = :topics
    end

    record = klass.create!(title: "Original", written_on: Date.today)

    klass.transaction do
      record.update!(title: "Changed")
      record.destroy
    end

    assert_equal ["Original", "Changed"], record.transaction_changes["title"]
  end

  test "transaction_changes unaffected by failed validation within transaction" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "people"
      validates :first_name, presence: true
    end

    person = klass.create!(first_name: "Sean")

    klass.transaction do
      person.update!(first_name: "Jim")
      person.update(first_name: nil)  # validation fails, returns false
      person.update!(first_name: "Final")
    end

    # The failed save should not corrupt transaction_changes;
    # transaction_changes spans the full transaction: Sean -> Final
    assert_equal ["Sean", "Final"], person.transaction_changes[:first_name]
  end

  private
    # Shared anonymous TouchLater/after_commit model used by the deferred-touch
    # sequence and the abort/raise record-reuse regressions. The touch toggles
    # stay inert unless a test sets them.
    def deferred_touch_person_class
      Class.new(ActiveRecord::Base) do
        self.table_name = :people

        attr_accessor :abort_touch, :raise_touch, :transaction_changes_log

        set_callback(:touch, :before) do
          throw :abort if abort_touch
          raise "touch callback failure" if raise_touch
        end

        after_commit do
          self.transaction_changes_log = transaction_changes.dup
        end
      end
    end

    def nested_transaction_classes
      {
        clean_parent: ActiveRecord::ConnectionAdapters::RestartParentTransaction,
        dirty_parent: ActiveRecord::ConnectionAdapters::SavepointTransaction,
      }
    end

    def touch_later_internal_state(record)
      {
        defer_touch_attrs: record.instance_variable_get(:@_defer_touch_attrs),
        deferred_touch_original_attributes: record.instance_variable_get(:@_deferred_touch_original_attributes),
        transaction_written_attribute_names: record.instance_variable_get(:@_transaction_written_attribute_names),
      }
    end
end
