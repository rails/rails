# frozen_string_literal: true

class Pane < ActiveRecord::Base
  belongs_to :window, counter_cache: true
  accepts_nested_attributes_for :window
end
