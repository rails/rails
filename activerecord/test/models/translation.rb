# frozen_string_literal: true

class Translation < ActiveRecord::Base
  belongs_to :attachment, optional: true

  validates :locale, presence: true
  validates :key, presence: true
  validates :value, presence: true
end
