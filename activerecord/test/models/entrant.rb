# frozen_string_literal: true

class Entrant < ActiveRecord::Base
  belongs_to :course
end
