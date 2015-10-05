require "cases/helper"
require 'models/company'

class Company
  has_many :latest_contracts, -> { order('created_at DESC') }, foreign_key: :contract_id
end

class AlwaysReflectAssociationsOnSTIBaseClassDescendants < ActiveRecord::TestCase
  def test_should_generate_valid_sql
    assert Firm.reflections.keys.include? 'latest_contracts'
  end
end
