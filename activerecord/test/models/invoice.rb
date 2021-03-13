# frozen_string_literal: true

class Invoice < ActiveRecord::Base
  has_many :line_items, autosave: true
  before_save { |record| record.balance = record.line_items.filter_map(&:amount).sum }
end
