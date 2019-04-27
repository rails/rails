# frozen_string_literal: true

class Session < ActiveRecord::Base
  has_many :sections, inverse_of: :session, autosave: true, dependent: :destroy
  has_many :seminars, through: :sections
end
