# frozen_string_literal: true

require "thread"
require "cases/helper"
require "models/person"
require "models/job"
require "models/reader"
require "models/ship"
require "models/legacy_thing"
require "models/personal_legacy_thing"
require "models/reference"
require "models/string_key_object"
require "models/car"
require "models/bulb"
require "models/engine"
require "models/wheel"
require "models/treasure"
require "models/frog"

class LockWithoutDefault < ActiveRecord::Base; end

class LockWithCustomColumnWithoutDefault < ActiveRecord::Base
  self.table_name = :lock_without_defaults_cust
  column_defaults # to test @column_defaults caching.
  self.locking_column = :custom_lock_version
end

class ReadonlyNameShip < Ship
  attr_readonly :name
end

class OptimisticLockingTest < ActiveRecord::TestCase
  fixtures :people, :legacy_things, :references, :string_key_objects, :peoples_treasures

  def test_quote_value_passed_lock_col
    p1 = Person.find(1)
    assert_equal 0, p1.lock_version

    p1.first_name = "anika2"
    p1.save!

    assert_equal 1, p1.lock_version
  end

  def test_non_integer_lock_existing
    s1 = StringKeyObject.find("record1")
    s2 = StringKeyObject.find("record1")
    assert_equal 0, s1.lock_version
    assert_equal 0, s2.lock_version

    s1.name = "updated record"
    s1.save!
    assert_equal 1, s1.lock_version
    assert_equal 0, s2.lock_version

    s2.name = "doubly updated record"
    assert_raise(ActiveRecord::StaleObjectError) { s2.save! }
  end

  def test_non_integer_lock_destroy
    s1 = StringKeyObject.find("record1")
    s2 = StringKeyObject.find("record1")
    assert_equal 0, s1.lock_version
    assert_equal 0, s2.lock_version

    s1.name = "updated record"
    s1.save!
    assert_equal 1, s1.lock_version
    assert_equal 0, s2.lock_version
    assert_raise(ActiveRecord::StaleObjectError) { s2.destroy }

    assert s1.destroy
    assert_predicate s1, :frozen?
    assert_predicate s1, :destroyed?
    assert_raises(ActiveRecord::RecordNotFound) { StringKeyObject.find("record1") }
  end

  def test_lock_existing
    p1 = Person.find(1)
    p2 = Person.find(1)
    assert_equal 0, p1.lock_version
    assert_equal 0, p2.lock_version

    p1.first_name = "stu"
    p1.save!
    assert_equal 1, p1.lock_version
    assert_equal 0, p2.lock_version

    p2.first_name = "sue"
    assert_raise(ActiveRecord::StaleObjectError) { p2.save! }
  end

  # See Lighthouse ticket #1966
  def test_lock_destroy
    p1 = Person.find(1)
    p2 = Person.find(1)
    assert_equal 0, p1.lock_version
    assert_equal 0, p2.lock_version

    p1.first_name = "stu"
    p1.save!
    assert_equal 1, p1.lock_version
    assert_equal 0, p2.lock_version

    assert_raises(ActiveRecord::StaleObjectError) { p2.destroy }

    assert p1.destroy
    assert_predicate p1, :frozen?
    assert_predicate p1, :destroyed?
    assert_raises(ActiveRecord::RecordNotFound) { Person.find(1) }
  end

  def test_lock_repeating
    p1 = Person.find(1)
    p2 = Person.find(1)
    assert_equal 0, p1.lock_version
    assert_equal 0, p2.lock_version

    p1.first_name = "stu"
    p1.save!
    assert_equal 1, p1.lock_version
    assert_equal 0, p2.lock_version

    p2.first_name = "sue"
    assert_raise(ActiveRecord::StaleObjectError) { p2.save! }
    p2.first_name = "sue2"
    assert_raise(ActiveRecord::StaleObjectError) { p2.save! }
  end

  def test_lock_new
    p1 = Person.new(first_name: "anika")
    assert_equal 0, p1.lock_version

    p1.first_name = "anika2"
    p1.save!
    p2 = Person.find(p1.id)
    assert_equal 0, p1.lock_version
    assert_equal 0, p2.lock_version

    p1.first_name = "anika3"
    p1.save!
    assert_equal 1, p1.lock_version
    assert_equal 0, p2.lock_version

    p2.first_name = "sue"
    assert_raise(ActiveRecord::StaleObjectError) { p2.save! }
  end

  def test_lock_exception_record
    p1 = Person.new(first_name: "mira")
    assert_equal 0, p1.lock_version

    p1.first_name = "mira2"
    p1.save!
    p2 = Person.find(p1.id)
    assert_equal 0, p1.lock_version
    assert_equal 0, p2.lock_version

    p1.first_name = "mira3"
    p1.save!

    p2.first_name = "sue"
    error = assert_raise(ActiveRecord::StaleObjectError) { p2.save! }
    assert_same error.record, p2
  end

  def test_lock_new_when_explicitly_passing_nil
    p1 = Person.new(first_name: "anika", lock_version: nil)
    p1.save!
    assert_equal 0, p1.lock_version
  end

  def test_lock_new_when_explicitly_passing_value
    p1 = Person.new(first_name: "Douglas Adams", lock_version: 42)
    p1.save!
    assert_equal 42, p1.lock_version
  end

  def test_touch_existing_lock
    p1 = Person.find(1)
    assert_equal 0, p1.lock_version

    p1.touch
    assert_equal 1, p1.lock_version
    assert_not_predicate p1, :changed?, "Changes should have been cleared"
    assert_predicate p1, :saved_changes?
    assert_equal ["lock_version", "updated_at"], p1.saved_changes.keys.sort
  end

  def test_touch_stale_object
    person = Person.create!(first_name: "Mehmet Emin")
    stale_person = Person.find(person.id)
    person.update_attribute(:gender, "M")

    assert_raises(ActiveRecord::StaleObjectError) do
      stale_person.touch
    end

    assert_not_predicate stale_person, :saved_changes?
  end

  def test_update_with_dirty_primary_key
    assert_raises(ActiveRecord::RecordNotUnique) do
      person = Person.find(1)
      person.id = 2
      person.save!
    end

    person = Person.find(1)
    person.id = 42
    person.save!

    assert Person.find(42)
    assert_raises(ActiveRecord::RecordNotFound) do
      Person.find(1)
    end
  end

  def test_delete_with_dirty_primary_key
    person = Person.find(1)
    person.id = 2
    person.delete

    assert Person.find(2)
    assert_raises(ActiveRecord::RecordNotFound) do
      Person.find(1)
    end
  end

  def test_destroy_with_dirty_primary_key
    person = Person.find(1)
    person.id = 2
    person.destroy

    assert Person.find(2)
    assert_raises(ActiveRecord::RecordNotFound) do
      Person.find(1)
    end
  end

  def test_update_with_dirty_locking_column
    person = Person.find(1)
    person.first_name = "Douglas Adams"
    person.lock_version = 42

    changes = {
      "first_name" => ["Michael", "Douglas Adams"],
      "lock_version" => [0, 42],
    }
    assert_equal changes, person.changes

    assert person.save!
    assert_empty person.changes
  end

  def test_explicit_update_lock_column_raise_error
    person = Person.find(1)

    person2 = Person.find(1)
    person2.lock_version = 42
    person2.save!

    assert_raises(ActiveRecord::StaleObjectError) do
      person.first_name = "Douglas Adams"
      person.lock_version = person2.lock_version

      changes = {
        "first_name" => ["Michael", "Douglas Adams"],
        "lock_version" => [0, 43],
      }
      assert_equal changes, person.changes

      person.save
    end
  end

  def test_lock_column_name_existing
    t1 = LegacyThing.find(1)
    t2 = LegacyThing.find(1)
    assert_equal 0, t1.version
    assert_equal 0, t2.version

    t1.tps_report_number = 700
    t1.save!
    assert_equal 1, t1.version
    assert_equal 0, t2.version

    t2.tps_report_number = 800
    assert_raise(ActiveRecord::StaleObjectError) { t2.save! }
  end

  def test_lock_column_is_mass_assignable
    p1 = Person.create(first_name: "bianca")
    assert_equal 0, p1.lock_version
    assert_equal p1.lock_version, Person.new(p1.attributes).lock_version

    p1.first_name = "bianca2"
    p1.save!
    assert_equal 1, p1.lock_version
    assert_equal p1.lock_version, Person.new(p1.attributes).lock_version
  end

  def test_lock_without_default_sets_version_to_zero
    t1 = LockWithoutDefault.new

    assert_equal 0, t1.lock_version
    assert_nil t1.lock_version_before_type_cast

    t1.save!
    t1.reload

    assert_equal 0, t1.lock_version
    assert_equal 0, t1.lock_version_before_type_cast
  end

  def test_touch_existing_lock_without_default_should_work_with_null_in_the_database
    ActiveRecord::Base.connection.execute("INSERT INTO lock_without_defaults(title) VALUES('title1')")
    t1 = LockWithoutDefault.last

    assert_equal 0, t1.lock_version
    assert_nil t1.lock_version_before_type_cast

    t1.touch

    assert_equal 1, t1.lock_version
    assert_not_predicate t1, :changed?
    assert_predicate t1, :saved_changes?
    assert_equal ["lock_version", "updated_at"], t1.saved_changes.keys.sort
  end

  def test_touch_stale_object_with_lock_without_default
    t1 = LockWithoutDefault.create!(title: "title1")
    stale_object = LockWithoutDefault.find(t1.id)

    t1.update!(title: "title2")

    assert_raises(ActiveRecord::StaleObjectError) do
      stale_object.touch
    end

    assert_not_predicate stale_object, :saved_changes?
  end

  def test_lock_without_default_should_work_with_null_in_the_database
    ActiveRecord::Base.connection.execute("INSERT INTO lock_without_defaults(title) VALUES('title1')")
    t1 = LockWithoutDefault.last
    t2 = LockWithoutDefault.find(t1.id)

    assert_equal 0, t1.lock_version
    assert_nil t1.lock_version_before_type_cast
    assert_equal 0, t2.lock_version
    assert_nil t2.lock_version_before_type_cast

    t1.title = "new title1"
    t2.title = "new title2"

    assert_nothing_raised { t1.save! }
    assert_equal 1, t1.lock_version
    assert_equal "new title1", t1.title

    assert_raise(ActiveRecord::StaleObjectError) { t2.save! }
    assert_equal 0, t2.lock_version
    assert_equal "new title2", t2.title
  end

  def test_lock_without_default_queries_count
    t1 = LockWithoutDefault.create(title: "title1")

    assert_equal "title1", t1.title
    assert_equal 0, t1.lock_version

    assert_queries(1) { t1.update(title: "title2") }

    t1.reload
    assert_equal "title2", t1.title
    assert_equal 1, t1.lock_version

    t2 = LockWithoutDefault.new(title: "title1")

    assert_queries(1) { t2.save! }

    t2.reload
    assert_equal "title1", t2.title
    assert_equal 0, t2.lock_version
  end

  def test_lock_with_custom_column_without_default_sets_version_to_zero
    t1 = LockWithCustomColumnWithoutDefault.new

    assert_equal 0, t1.custom_lock_version
    assert_nil t1.custom_lock_version_before_type_cast

    t1.save!
    t1.reload

    assert_equal 0, t1.custom_lock_version
    assert_equal 0, t1.custom_lock_version_before_type_cast
  end

  def test_lock_with_custom_column_without_default_should_work_with_null_in_the_database
    ActiveRecord::Base.connection.execute("INSERT INTO lock_without_defaults_cust(title) VALUES('title1')")

    t1 = LockWithCustomColumnWithoutDefault.last
    t2 = LockWithCustomColumnWithoutDefault.find(t1.id)

    assert_equal 0, t1.custom_lock_version
    assert_nil t1.custom_lock_version_before_type_cast
    assert_equal 0, t2.custom_lock_version
    assert_nil t2.custom_lock_version_before_type_cast

    t1.title = "new title1"
    t2.title = "new title2"

    assert_nothing_raised { t1.save! }
    assert_equal 1, t1.custom_lock_version
    assert_equal "new title1", t1.title

    assert_raise(ActiveRecord::StaleObjectError) { t2.save! }
    assert_equal 0, t2.custom_lock_version
    assert_equal "new title2", t2.title
  end

  def test_lock_with_custom_column_without_default_queries_count
    t1 = LockWithCustomColumnWithoutDefault.create(title: "title1")

    assert_equal "title1", t1.title
    assert_equal 0, t1.custom_lock_version

    assert_queries(1) { t1.update(title: "title2") }

    t1.reload
    assert_equal "title2", t1.title
    assert_equal 1, t1.custom_lock_version

    t2 = LockWithCustomColumnWithoutDefault.new(title: "title1")

    assert_queries(1) { t2.save! }

    t2.reload
    assert_equal "title1", t2.title
    assert_equal 0, t2.custom_lock_version
  end

  def test_readonly_attributes
    assert_equal Set.new([ "name" ]), ReadonlyNameShip.readonly_attributes

    s = ReadonlyNameShip.create(name: "unchangeable name")
    s.reload
    assert_equal "unchangeable name", s.name

    s.update(name: "changed name")
    s.reload
    assert_equal "unchangeable name", s.name
  end

  def test_quote_table_name
    ref = references(:michael_magician)
    ref.favourite = !ref.favourite
    assert ref.save
  end

  # Useful for partial updates, don't only update the lock_version if there
  # is nothing else being updated.
  def test_update_without_attributes_does_not_only_update_lock_version
    assert_nothing_raised do
      p1 = Person.create!(first_name: "anika")
      lock_version = p1.lock_version
      p1.save
      p1.reload
      assert_equal lock_version, p1.lock_version
    end
  end

  def test_counter_cache_with_touch_and_lock_version
    car = Car.create!

    assert_equal 0, car.wheels_count
    assert_equal 0, car.lock_version

    previously_updated_at = car.updated_at
    previously_wheels_owned_at = car.wheels_owned_at
    travel(1.second) do
      Wheel.create!(wheelable: car)
    end

    assert_equal 1, car.reload.wheels_count
    assert_equal 1, car.lock_version
    assert_operator previously_updated_at, :<, car.updated_at
    assert_operator previously_wheels_owned_at, :<, car.wheels_owned_at

    previously_updated_at = car.updated_at
    previously_wheels_owned_at = car.wheels_owned_at
    travel(2.second) do
      car.wheels.first.update(size: 42)
    end

    assert_equal 1, car.reload.wheels_count
    assert_equal 2, car.lock_version
    assert_operator previously_updated_at, :<, car.updated_at
    assert_operator previously_wheels_owned_at, :<, car.wheels_owned_at

    previously_updated_at = car.updated_at
    previously_wheels_owned_at = car.wheels_owned_at
    travel(3.second) do
      car.wheels.first.destroy!
    end

    assert_equal 0, car.reload.wheels_count
    assert_equal 3, car.lock_version
    assert_operator previously_updated_at, :<, car.updated_at
    assert_operator previously_wheels_owned_at, :<, car.wheels_owned_at

    car.wheels << Wheel.create!
    assert_equal 1, car.wheels_count
    assert_equal 4, car.lock_version
    assert_not car.lock_version_changed?
    assert_nothing_raised { car.update(name: "herbie") }
  end

  def test_polymorphic_destroy_with_dependencies_and_lock_version
    car = Car.create!

    assert_difference "car.wheels.count"  do
      car.wheels.create
    end
    assert_difference "car.wheels.count", -1  do
      car.reload.destroy
    end
    assert_predicate car, :destroyed?
  end

  def test_removing_has_and_belongs_to_many_associations_upon_destroy
    p = RichPerson.create! first_name: "Jon"
    p.treasures.create!
    assert_not_empty p.treasures
    p.destroy
    assert_empty p.treasures
    assert_empty RichPerson.connection.select_all("SELECT * FROM peoples_treasures WHERE rich_person_id = 1")
  end

  def test_yaml_dumping_with_lock_column
    t1 = LockWithoutDefault.new
    t2 = YAML.load(YAML.dump(t1))

    assert_equal t1.attributes, t2.attributes
  end
end

class OptimisticLockingWithSchemaChangeTest < ActiveRecord::TestCase
  fixtures :people, :legacy_things, :references

  # need to disable transactional tests, because otherwise the sqlite3
  # adapter (at least) chokes when we try and change the schema in the middle
  # of a test (see test_increment_counter_*).
  self.use_transactional_tests = false

  { lock_version: Person, custom_lock_version: LegacyThing }.each do |name, model|
    define_method("test_increment_counter_updates_#{name}") do
      counter_test model, 1 do |id|
        model.increment_counter :test_count, id
      end
    end

    define_method("test_decrement_counter_updates_#{name}") do
      counter_test model, -1 do |id|
        model.decrement_counter :test_count, id
      end
    end

    define_method("test_update_counters_updates_#{name}") do
      counter_test model, 1 do |id|
        model.update_counters id, test_count: 1
      end
    end
  end

  # See Lighthouse ticket #1966
  def test_destroy_dependents
    # Establish dependent relationship between Person and PersonalLegacyThing
    add_counter_column_to(Person, "personal_legacy_things_count")
    PersonalLegacyThing.reset_column_information

    # Make sure that counter incrementing doesn't cause problems
    p1 = Person.new(first_name: "fjord")
    p1.save!
    t = PersonalLegacyThing.new(person: p1)
    t.save!
    p1.reload
    assert_equal 1, p1.personal_legacy_things_count
    assert p1.destroy
    assert_equal true, p1.frozen?
    assert_raises(ActiveRecord::RecordNotFound) { Person.find(p1.id) }
    assert_raises(ActiveRecord::RecordNotFound) { PersonalLegacyThing.find(t.id) }
  ensure
    remove_counter_column_from(Person, "personal_legacy_things_count")
    PersonalLegacyThing.reset_column_information
  end

  def test_destroy_existing_object_with_locking_column_value_null_in_the_database
    ActiveRecord::Base.connection.execute("INSERT INTO lock_without_defaults(title) VALUES('title1')")
    t1 = LockWithoutDefault.last

    assert_equal 0, t1.lock_version
    assert_nil t1.lock_version_before_type_cast

    t1.destroy

    assert_predicate t1, :destroyed?
  end

  def test_destroy_stale_object
    t1 = LockWithoutDefault.create!(title: "title1")
    stale_object = LockWithoutDefault.find(t1.id)

    t1.update!(title: "title2")

    assert_raises(ActiveRecord::StaleObjectError) do
      stale_object.destroy!
    end

    assert_not_predicate stale_object, :destroyed?
  end

  private
    def add_counter_column_to(model, col = "test_count")
      model.connection.add_column model.table_name, col, :integer, null: false, default: 0
      model.reset_column_information
    end

    def remove_counter_column_from(model, col = :test_count)
      model.connection.remove_column model.table_name, col
      model.reset_column_information
    end

    def counter_test(model, expected_count)
      add_counter_column_to(model)
      object = model.first
      assert_equal 0, object.test_count
      assert_equal 0, object.send(model.locking_column)
      yield object.id
      object.reload
      assert_equal expected_count, object.test_count
      assert_equal 1, object.send(model.locking_column)
    ensure
      remove_counter_column_from(model)
    end
end

# TODO: test against the generated SQL since testing locking behavior itself
# is so cumbersome. Will deadlock Ruby threads if the underlying db.execute
# blocks, so separate script called by Kernel#system is needed.
# (See exec vs. async_exec in the PostgreSQL adapter.)
unless in_memory_db?
  class PessimisticLockingTest < ActiveRecord::TestCase
    self.use_transactional_tests = false
    fixtures :people, :readers

    def setup
      Person.connection_pool.clear_reloadable_connections!
      # Avoid introspection queries during tests.
      Person.columns; Reader.columns
    end

    # Test typical find.
    def test_sane_find_with_lock
      assert_nothing_raised do
        Person.transaction do
          Person.lock.find(1)
        end
      end
    end

    # PostgreSQL protests SELECT ... FOR UPDATE on an outer join.
    unless current_adapter?(:PostgreSQLAdapter)
      # Test locked eager find.
      def test_eager_find_with_lock
        assert_nothing_raised do
          Person.transaction do
            Person.includes(:readers).lock.find(1)
          end
        end
      end
    end

    def test_lock_does_not_raise_when_the_object_is_not_dirty
      person = Person.find 1
      assert_nothing_raised do
        person.lock!
      end
    end

    def test_lock_raises_when_the_record_is_dirty
      person = Person.find 1
      person.first_name = "fooman"
      assert_raises(RuntimeError) do
        person.lock!
      end
    end

    def test_locking_in_after_save_callback
      assert_nothing_raised do
        frog = ::Frog.create(name: "Old Frog")
        frog.name = "New Frog"
        assert_not_deprecated do
          frog.save!
        end
      end
    end

    def test_with_lock_commits_transaction
      person = Person.find 1
      person.with_lock do
        person.first_name = "fooman"
        person.save!
      end
      assert_equal "fooman", person.reload.first_name
    end

    def test_with_lock_rolls_back_transaction
      person = Person.find 1
      old = person.first_name
      person.with_lock do
        person.first_name = "fooman"
        person.save!
        raise "oops"
      end rescue nil
      assert_equal old, person.reload.first_name
    end

    if current_adapter?(:PostgreSQLAdapter)
      def test_lock_sending_custom_lock_statement
        Person.transaction do
          person = Person.find(1)
          assert_sql(/LIMIT \$?\d FOR SHARE NOWAIT/) do
            person.lock!("FOR SHARE NOWAIT")
          end
        end
      end
    end

    def test_no_locks_no_wait
      first, second = duel { Person.find 1 }
      assert first.end > second.end
    end

    def test_lock_on_delete_all
      Person.transaction do
        assert_sql(/FOR UPDATE/) do
          Person.all.lock!.delete_all
        end
      end
    end

    def test_lock_on_update_all
      Person.transaction do
        assert_sql(/FOR UPDATE/) do
          scope = Person.all.lock!
          scope.update_all(first_name: "David")
        end
      end
    end

    private
      def duel(zzz = 5)
        t0, t1, t2, t3 = nil, nil, nil, nil

        a = Thread.new do
          t0 = Time.now
          Person.transaction do
            yield
            sleep zzz       # block thread 2 for zzz seconds
          end
          t1 = Time.now
        end

        b = Thread.new do
          sleep zzz / 2.0   # ensure thread 1 tx starts first
          t2 = Time.now
          Person.transaction { yield }
          t3 = Time.now
        end

        a.join
        b.join

        assert t1 > t0 + zzz
        assert t2 > t0
        assert t3 > t2
        [t0.to_f..t1.to_f, t2.to_f..t3.to_f]
      end
  end
end
