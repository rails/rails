class Computer < ActiveRecord::Base
  belongs_to :developer, :foreign_key=>'developer'
end

