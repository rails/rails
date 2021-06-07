# frozen_string_literal: true

require "cases/helper"
require "models/human"

class AutomaticInverseFindingTests < ActiveRecord::TestCase
  # Test explicit_select_column_names config
  # The test need to run within unprepared_statement
  # otherise the SELECT come from cache or polluted it
  def test_with_explicit_select_column_names
    Human.connection.unprepared_statement do
      with_explicit_select_column_names do
        human = Human.create!
        assert_sql(/SELECT "humans"."id", "humans"."name" FROM/) do
          Human.find human.id
        end
      end
    end
  end

  def test_without_explicit_select_column_names
    human = Human.create!
    assert_sql(/SELECT "humans".\* FROM/) do
      Human.find human.id
    end
  end
end
