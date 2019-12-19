# frozen_string_literal: true

class Seminar < ActiveRecord::Base
  has_many :sections, inverse_of: :seminar, autosave: true, dependent: :destroy
  has_many :sessions, through: :sections
end
