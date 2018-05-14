# frozen_string_literal: true

class LineItem < ActiveRecord::Base
  belongs_to :invoice, touch: true
end
