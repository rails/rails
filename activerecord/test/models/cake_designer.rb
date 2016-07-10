class CakeDesigner < ActiveRecord::Base
  has_one :chef, as: :employable

  delegate :department_id, to: :employable
end
