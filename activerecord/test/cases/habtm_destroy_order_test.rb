require "cases/helper"
require "models/lesson"
require "models/student"

class HabtmDestroyOrderTest < ActiveRecord::TestCase
  test "may not delete a lesson with students" do
    sicp = Lesson.new(:name => "SICP")
    ben = Student.new(:name => "Ben Bitdiddle")
    sicp.students << ben
    sicp.save!
    assert_raises LessonError do
      assert_no_difference('Lesson.count') do
        sicp.destroy
      end
    end
  end
end
