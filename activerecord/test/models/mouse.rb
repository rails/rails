# frozen_string_literal: true

class Mouse < ActiveRecord::Base
  has_many :squeaks, autosave: true
  validates :name, presence: true
end
