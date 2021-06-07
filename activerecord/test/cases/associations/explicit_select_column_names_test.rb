# frozen_string_literal: true

require "cases/helper"
require "models/human"

class AutomaticInverseFindingTests < ActiveRecord::TestCase
  def test_with_explicit_select_column_names
    with_explicit_select_column_names do
      human = Human.create!
      assert_sql(/SELECT "humans"."id", "humans"."name" FROM/) do
        Human.find human.id
      end
    end
  end
end
