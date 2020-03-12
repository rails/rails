# frozen_string_literal: true

class House < ActiveRecord::Base
  has_many :lounges, :dependent => :destroy, :inverse_of => :house
end