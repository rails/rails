# frozen_string_literal: true

class Electron < ActiveRecord::Base
  belongs_to :molecule, optional: true

  validates_presence_of :name
end
