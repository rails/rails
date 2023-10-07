# frozen_string_literal: true

class Squeak < ActiveRecord::Base
  belongs_to :mouse, optional: true
  accepts_nested_attributes_for :mouse
end
