# frozen_string_literal: true

class FamilyTree < ActiveRecord::Base
  belongs_to :member, class_name: "User", foreign_key: "member_id", optional: true
  belongs_to :family, optional: true
end
