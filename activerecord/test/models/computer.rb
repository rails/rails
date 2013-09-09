class Computer < ApplicationRecord
  belongs_to :developer, :foreign_key=>'developer'
end
