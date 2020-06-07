# frozen_string_literal: true

class Dashboard < ActiveRecord::Base
  self.primary_key = :dashboard_id

  has_one :speedometer
end
