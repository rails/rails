# frozen_string_literal: true

class Treaty < ActiveRecord::Base
  has_and_belongs_to_many :countries
end
