# frozen_string_literal: true

class Recipe < ActiveRecord::Base
  belongs_to :chef
end
