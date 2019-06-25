# frozen_string_literal: true

class Receipt < ActiveRecord::Base
  belongs_to :customer
end
