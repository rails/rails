require 'abstract_unit'
require 'fixtures/topic'

class ReadOnlyTest < Test::Unit::TestCase
  fixtures :topics

  def test_cant_save_readonly_record
    topic = Topic.find(:first)
    assert !topic.readonly?

    topic.readonly!
    assert topic.readonly?

    assert_nothing_raised do
      topic.content = 'Luscious forbidden fruit.'
    end

    assert_raise(ActiveRecord::ReadOnlyRecord)  { topic.save  }
    assert_raise(ActiveRecord::ReadOnlyRecord)  { topic.save! }
  end

  def test_find_with_readonly_option
    Topic.find(:all).each { |t| assert !t.readonly? }
    Topic.find(:all, :readonly => false).each { |t| assert !t.readonly? }
    Topic.find(:all, :readonly => true).each { |t| assert t.readonly? }
  end

  def test_find_with_joins_option_implies_readonly
    Topic.find(:all, :joins => '').each { |t| assert t.readonly? }
  end
end
