# frozen_string_literal: true

class Event < ActiveRecord::Base
  validates_uniqueness_of :title
end
