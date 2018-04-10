# frozen_string_literal: true

class Game < ActiveRecord::Base
  has_one :game_board
  belongs_to :game_owner
  belongs_to :game_collection
end
