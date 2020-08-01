# frozen_string_literal: true

require "cases/helper"
require "models/default"

class ReturningTest < ActiveRecord::TestCase
  fixtures :books

  # def setup
  #   Arel::Table.engine = nil # should not rely on the global Arel::Table.engine
  # end

  # def teardown
  #   Arel::Table.engine = ActiveRecord::Base
  # end

  def test_create_record
    skip unless supports_insert_returning?

    new_default = Default.create!
    assert new_default.persisted?
    assert new_default.modified_date_function != nil
    assert new_default.modified_date == nil
  end
end
