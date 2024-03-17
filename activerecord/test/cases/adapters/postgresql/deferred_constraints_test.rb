# frozen_string_literal: true

require "cases/helper"
require "models/author"

class PostgresqlDeferredConstraintsTest < ActiveRecord::PostgreSQLTestCase
  def setup
    @connection = ActiveRecord::Base.lease_connection
    @fk = @connection.foreign_keys("authors").first.name
    @other_fk = @connection.foreign_keys("lessons_students").first.name
  end

  def test_defer_constraints
    assert_raises ActiveRecord::InvalidForeignKey do
      @connection.set_constraints(:deferred)
      assert_nothing_raised do
        Author.create!(author_address_id: -1, name: "John Doe")
      end
      @connection.set_constraints(:immediate)
    end
  end

  def test_defer_constraints_with_specific_fk
    assert_raises ActiveRecord::InvalidForeignKey do
      @connection.set_constraints(:deferred, @fk)
      assert_nothing_raised do
        Author.create!(author_address_id: -1, name: "John Doe")
      end
      @connection.set_constraints(:immediate, @fk)
    end
  end

  def test_defer_constraints_with_multiple_fks
    assert_raises ActiveRecord::InvalidForeignKey do
      @connection.set_constraints(:deferred, @other_fk, @fk)
      assert_nothing_raised do
        Author.create!(author_address_id: -1, name: "John Doe")
      end
      @connection.set_constraints(:immediate, @other_fk, @fk)
    end
  end

  def test_defer_constraints_only_defers_single_fk
    @connection.set_constraints(:deferred, @other_fk)
    assert_raises ActiveRecord::InvalidForeignKey do
      Author.create!(author_address_id: -1, name: "John Doe")
    end
  end

  def test_set_constraints_requires_valid_value
    assert_raises ArgumentError do
      @connection.set_constraints(:invalid)
    end
  end
end
