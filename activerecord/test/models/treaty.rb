# frozen_string_literal: true

class Treaty < ActiveRecord::Base
  belongs_to :owner
  has_and_belongs_to_many :countries
end
