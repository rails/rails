# frozen_string_literal: true

class GameOwner < ActiveRecord::Base
  has_many :games
end
