# frozen_string_literal: true

class Invoice < ActiveRecord::Base
  has_many :line_items, autosave: true
  has_many :shipping_lines, -> { from("shipping_lines") }, autosave: true
  before_save { |record| record.balance = record.line_items.map(&:amount).sum }
end
