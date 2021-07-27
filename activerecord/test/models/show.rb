# frozen_string_literal: true

class Show < ActiveRecord::Base
  has_many :reviews, as: :reviewable
end
