# frozen_string_literal: true

class HmtCourse < ActiveRecord::Base
  has_many :hmt_enrollments
  has_many :hmt_students, through: :hmt_enrollments
end
