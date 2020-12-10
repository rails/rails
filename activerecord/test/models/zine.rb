# frozen_string_literal: true

class Zine < ActiveRecord::Base
  has_many :interests, inverse_of: :zine, foreign_key: "zine_id"
end
