# frozen_string_literal: true

class Broken < ActiveRecord::Base
  self.table_name = "auto_id_tests"
  self.primary_key = "auto_id"

  belongs_to :foo
  has_one :bar

  def persisted?
    false
  end
end
