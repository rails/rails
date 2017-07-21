# frozen_string_literal: true

class Tree < ActiveRecord::Base
  has_many :nodes, dependent: :destroy
end
