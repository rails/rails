# frozen_string_literal: true

class Album < ActiveRecord::Base
  has_many :reviews, as: :reviewable
end
