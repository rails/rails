# frozen_string_literal: true

require "cases/helper"
require "models/entrant"
require "models/bird"
require "models/course"

class MultipleDbTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  def setup
    @courses  = create_fixtures("courses")
    @colleges = create_fixtures("colleges")
    @entrants = create_fixtures("entrants")
  end

  def test_connected
    assert_not_nil Entrant.lease_connection
    assert_not_nil Course.lease_connection
  end

  def test_proper_connection
    assert_not_equal(Entrant.lease_connection, Course.lease_connection)
    assert_equal(Entrant.lease_connection, Entrant.retrieve_connection)
    assert_equal(Course.lease_connection, Course.retrieve_connection)
    assert_equal(ActiveRecord::Base.lease_connection, Entrant.lease_connection)
  end

  def test_swapping_the_connection
    old_spec_name, Course.connection_specification_name = Course.connection_specification_name, "ActiveRecord::Base"
    assert_equal(Entrant.lease_connection, Course.lease_connection)
  ensure
    Course.connection_specification_name = old_spec_name
  end

  def test_find
    c1 = Course.find(1)
    assert_equal "Ruby Development", c1.name
    c2 = Course.find(2)
    assert_equal "Java Development", c2.name
    e1 = Entrant.find(1)
    assert_equal "Ruby Developer", e1.name
    e2 = Entrant.find(2)
    assert_equal "Ruby Guru", e2.name
    e3 = Entrant.find(3)
    assert_equal "Java Lover", e3.name
  end

  def test_associations
    c1 = Course.find(1)
    assert_equal 2, c1.entrants.count
    e1 = Entrant.find(1)
    assert_equal e1.course.id, c1.id
    c2 = Course.find(2)
    assert_equal 1, c2.entrants.count
    e3 = Entrant.find(3)
    assert_equal e3.course.id, c2.id
  end

  def test_course_connection_should_survive_reloads
    assert Course.lease_connection

    assert Object.send(:remove_const, :Course)
    assert load("models/course.rb")

    assert Course.lease_connection
  end

  def test_transactions_across_databases
    c1 = Course.find(1)
    e1 = Entrant.find(1)

    begin
      Course.transaction do
        Entrant.transaction do
          c1.name = "Typo"
          e1.name = "Typo"
          c1.save
          e1.save
          raise "No I messed up."
        end
      end
    rescue
      # Yup caught it
    end

    assert_equal "Typo", c1.name
    assert_equal "Typo", e1.name

    assert_equal "Ruby Development", Course.find(1).name
    assert_equal "Ruby Developer", Entrant.find(1).name
  end

  def test_connection
    assert_same Entrant.lease_connection, Bird.lease_connection
    assert_not_same Entrant.lease_connection, Course.lease_connection
  end

  unless in_memory_db?
    def test_count_on_custom_connection
      assert_equal ARUnit2Model.lease_connection, College.lease_connection
      assert_not_equal ActiveRecord::Base.lease_connection, College.lease_connection
      assert_equal 1, College.count
    end

    def test_associations_should_work_when_model_has_no_connection
      assert_nothing_raised do
        College.first.courses.first
      end
    end

    if current_adapter?(:SQLite3Adapter)
      def test_sqlite_joins_from_primary_to_custom_connection_attach_the_custom_database
        entrants = Entrant.joins(:course).where(courses: { name: "Ruby Development" }).order(:id).pluck(:name)

        assert_equal ["Ruby Developer", "Ruby Guru"], entrants
      end

      def test_sqlite_joins_from_custom_connection_to_primary_attach_the_primary_database
        assert_equal 3, Course.joins(:entrants).count
      end

      def test_sqlite_attached_databases_do_not_leak_between_queries
        assert_equal 3, Course.joins(:entrants).count

        assert_raises(ActiveRecord::StatementInvalid) do
          Course.lease_connection.execute("SELECT * FROM entrants")
        end
      end

      def test_sqlite_does_not_collect_attached_database_from_raw_sql_join
        assert_raises(ActiveRecord::StatementInvalid) do
          Entrant.joins("INNER JOIN courses ON courses.id = entrants.course_id").load
        end
      end
    end
  end

  def test_exception_contains_connection_pool
    error = assert_raises(ActiveRecord::StatementInvalid) do
      Course.where(wrong_column: "wrong").first!
    end

    assert_equal Course.lease_connection.pool, error.connection_pool
  end

  def test_exception_contains_correct_pool
    course_conn = Course.lease_connection
    entrant_conn = Entrant.lease_connection

    assert_not_equal course_conn, entrant_conn

    course_error = assert_raises(ActiveRecord::StatementInvalid) do
      course_conn.execute("SELECT * FROM entrants")
    end

    assert_equal course_conn.pool, course_error.connection_pool

    entrant_error = assert_raises(ActiveRecord::StatementInvalid) do
      entrant_conn.execute("SELECT * FROM courses")
    end

    assert_equal entrant_conn.pool, entrant_error.connection_pool
  end
end
