# frozen_string_literal: true

class Restaurant::Menu < ActiveRecord::Base
  has_many :reviews, as: :reviewable
end
