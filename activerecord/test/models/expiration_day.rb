# frozen_string_literal: true

class ExpirationDay < ActiveRecord::Base
  belongs_to :day

  has_many :assembly_lots
end
