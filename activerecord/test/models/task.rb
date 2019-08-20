# frozen_string_literal: true

class Task < ActiveRecord::Base
  def updated_at
    ending
  end
end
