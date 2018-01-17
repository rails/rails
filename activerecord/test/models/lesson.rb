# frozen_string_literal: true

class LessonError < Exception
end

class Lesson < ActiveRecord::Base
  has_and_belongs_to_many :students
  before_destroy :ensure_no_students

  def ensure_no_students
    raise LessonError unless students.empty?
  end
end
