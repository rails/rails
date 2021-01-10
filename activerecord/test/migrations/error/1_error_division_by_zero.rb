# frozen_string_literal: true

class ErrorDivisionByZero < ActiveRecord::Migration::Current
  def self.up
    raise 1/0
  end

  def self.down
    raise 1/0
  end
end
