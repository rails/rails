# frozen_string_literal: true

class Food < ActiveRecord::Base
  belongs_to :parrot
end
