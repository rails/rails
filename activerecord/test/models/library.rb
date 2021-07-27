# frozen_string_literal: true

class Library < ActiveRecord::Base
  has_many :reviews, as: :reviewable
end
