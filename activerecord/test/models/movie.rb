# frozen_string_literal: true

class Movie < ActiveRecord::Base
  self.primary_key = 'movieid'

  validates_presence_of :name
end
