# frozen_string_literal: true

class MemberType < ActiveRecord::Base
  has_many :members
end
