require "cases/helper"
require 'models/club'
require 'models/membership'
require 'models/category'
require 'models/lesson'
require 'models/student'

class QuestionMethodsTest < ActiveRecord::TestCase
  fixtures :clubs, :memberships, :categories

  def test_question_method_to_belongs_to_association
    club = Club.create
    club.category = Category.create(name: "category")
    assert club.category?

    club = Club.create
    assert_not club.category?
  end

  def test_question_method_to_has_one_association
    club = Club.create
    club.sponsor = Sponsor.create
    assert club.sponsor?

    club = Club.create
    assert_not club.sponsor?
  end

  def test_question_method_to_has_many_association
    club = Club.create
    club.memberships.create!
    assert club.memberships?

    club = Club.create
    assert_not club.memberships?
  end

  def test_question_method_to_has_and_belongs_to_many_association
    lesson = Lesson.create
    lesson.students.create!
    assert lesson.students?

    lesson = Lesson.create
    assert_not lesson.students?
  end
end
