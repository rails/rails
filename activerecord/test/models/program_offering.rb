# frozen_string_literal: true

class ProgramOffering < ActiveRecord::Base
  belongs_to :club
  belongs_to :program
end
