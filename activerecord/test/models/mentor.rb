# frozen_string_literal: true

class Mentor < ActiveRecord::Base
  has_many :developers
end
