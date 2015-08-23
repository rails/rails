# frozen_string_literal: true

class HmtStudent < ActiveRecord::Base
  has_many :hmt_enrollments
  has_many :hmt_courses, through: :hmt_enrollments
end
