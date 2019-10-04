# frozen_string_literal: true

class CurrenciesHaveAmounts < ActiveRecord::Migration::Current
  def change
    add_column :currencies, :amount, :decimal
  end
end
