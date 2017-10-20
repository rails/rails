# frozen_string_literal: true

class Chef < ActiveRecord::Base
  belongs_to :employable, polymorphic: true
  has_many :recipes
end

class ChefList < Chef
  belongs_to :employable_list, polymorphic: true
end
