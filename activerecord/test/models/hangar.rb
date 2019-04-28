# frozen_string_literal: true

class Hangar < ActiveRecord::Base
  belongs_to :pilot

  has_many :starfighters
end
