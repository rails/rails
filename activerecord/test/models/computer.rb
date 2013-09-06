class Computer < ApplicationModel
  belongs_to :developer, :foreign_key=>'developer'
end
