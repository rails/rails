class Task < ApplicationRecord
  def updated_at
    ending
  end
end
