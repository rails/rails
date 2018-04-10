# frozen_string_literal: true

class GameCollection < ActiveRecord::Base
  has_many :games
end
