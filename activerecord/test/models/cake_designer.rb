# frozen_string_literal: true

class CakeDesigner < ActiveRecord::Base
  has_one :chef, as: :employable
end
