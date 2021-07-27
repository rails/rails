# frozen_string_literal: true

class Manga < ActiveRecord::Base
  has_many :reviews, as: :reviewable
end
