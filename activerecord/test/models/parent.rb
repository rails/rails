# frozen_string_literal: true

class Parent < ActiveRecord::Base
  has_one :child, inverse_of: :parent, autosave: true
  belongs_to :grandparent, inverse_of: :parent, autosave: true

  @@foo = 0

  after_validation :foo

  def foo
    @@foo += 1
  end
end
