# frozen_string_literal: true

class Restaurant < ActiveRecord::Base
  has_many :reviews, as: :reviewable
end
