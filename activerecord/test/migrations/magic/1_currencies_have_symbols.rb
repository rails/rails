# frozen_string_literal: true
# coding: ISO-8859-15

class CurrenciesHaveSymbols < ActiveRecord::Migration::Current
  def self.up
    # We use € for default currency symbol
    add_column 'currencies', 'symbol', :string, default: '€'
  end

  def self.down
    remove_column 'currencies', 'symbol'
  end
end
