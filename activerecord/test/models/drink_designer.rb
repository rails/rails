# frozen_string_literal: true

class DrinkDesigner < ActiveRecord::Base
  has_one :chef, as: :employable
end

class MocktailDesigner < DrinkDesigner
end
