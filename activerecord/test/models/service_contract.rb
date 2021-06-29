# frozen_string_literal: true

class ServiceContract < ActiveRecord::Base
  def self.active
    where(expires_at: nil).or(expiring)
  end

  def self.expiring
    where("expires_at > ?", Time.current)
  end
end
