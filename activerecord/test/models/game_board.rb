# frozen_string_literal: true

class GameBoard < ActiveRecord::Base
  belongs_to :game
  has_one :game_owner, through: :game
  has_one :game_collection, through: :game
end
