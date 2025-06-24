# frozen_string_literal: true

class Computer < ActiveRecord::Base
  belongs_to :developer, foreign_key: "developer"
  has_one :firm, through: :developer
end
