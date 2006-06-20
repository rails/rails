require 'abstract_unit'
require 'fixtures/person'
require 'fixtures/legacy_thing'

class OptimisticLockingTest < Test::Unit::TestCase
  fixtures :people, :legacy_things

  def test_lock_existing
    p1 = Person.find(1)
    p2 = Person.find(1)

    p1.first_name = "Michael"
    p1.save

    assert_raises(ActiveRecord::StaleObjectError) {
      p2.first_name = "should fail"
      p2.save
    }
  end

  def test_lock_new
    p1 = Person.create({ "first_name"=>"anika"})
    p2 = Person.find(p1.id)
    assert_equal p1.id, p2.id
    p1.first_name = "Anika"
    p1.save

    assert_raises(ActiveRecord::StaleObjectError) {
      p2.first_name = "should fail"
      p2.save
    }
  end

  def test_lock_column_name_existing
    t1 = LegacyThing.find(1)
    t2 = LegacyThing.find(1)
    t1.tps_report_number = 400
    t1.save

    assert_raises(ActiveRecord::StaleObjectError) {
      t2.tps_report_number = 300
      t2.save
    }
  end
end


# TODO: test against the generated SQL since testing locking behavior itself
# is so cumbersome. Will deadlock Ruby threads if the underlying db.execute
# blocks, so separate script called by Kernel#system is needed.
# (See exec vs. async_exec in the PostgreSQL adapter.)
class PessimisticLockingTest < Test::Unit::TestCase
  self.use_transactional_fixtures = false
  fixtures :people

  def setup
    @allow_concurrency = ActiveRecord::Base.allow_concurrency
    ActiveRecord::Base.allow_concurrency = true
  end

  def teardown
    ActiveRecord::Base.allow_concurrency = @allow_concurrency
  end

  # Test that the adapter doesn't blow up on add_lock!
  def test_sane_find_with_lock
    assert_nothing_raised do
      Person.transaction do
        Person.find 1, :lock => true
      end
    end
  end

  # Test no-blowup for scoped lock.
  def test_sane_find_with_lock
    assert_nothing_raised do
      Person.transaction do
        Person.with_scope(:find => { :lock => true }) do
          Person.find 1
        end
      end
    end
  end

  # Locking a record reloads it.
  def test_sane_lock_method
    assert_nothing_raised do
      Person.transaction do
        person = Person.find 1
        old, person.first_name = person.first_name, 'fooman'
        person.lock!
        assert_equal old, person.first_name
      end
    end
  end

  if current_adapter?(:PostgreSQLAdapter)
    def test_no_locks_no_wait
      first, second = duel { Person.find 1 }
      assert first.end > second.end
    end

    def test_second_lock_waits
      first, second = duel { Person.find 1, :lock => true }
      assert second.end > first.end
    end

    protected
      def duel(zzz = 0.2)
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
