# frozen_string_literal: true

class Day < ActiveRecord::Base
  has_one :expiration_day

  has_many :assembly_lots
end
