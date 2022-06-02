# frozen_string_literal: true

class NumericData < ActiveRecord::Base
  self.table_name = "numeric_data"
  # Decimal columns with 0 scale being automatically treated as integers
  # is deprecated, and will be removed in a future version of Rails.
  attribute :world_population, :big_integer
  attribute :my_house_population, :big_integer
  attribute :atoms_in_universe, :big_integer

  alias_attribute :new_bank_balance, :bank_balance
end
