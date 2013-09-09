class LineItem < ApplicationRecord
  belongs_to :invoice, :touch => true
end
