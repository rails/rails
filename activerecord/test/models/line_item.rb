class LineItem < ApplicationModel
  belongs_to :invoice, :touch => true
end
