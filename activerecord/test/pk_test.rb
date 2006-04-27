require "#{File.dirname(__FILE__)}/abstract_unit"
require 'fixtures/topic'
require 'fixtures/reply'
require 'fixtures/subscriber'
require 'fixtures/movie'
require 'fixtures/keyboard'

class PrimaryKeysTest < Test::Unit::TestCase
  fixtures :topics, :subscribers, :movies

  def test_integer_key
    topic = Topic.find(1)
    assert_equal(topics(:first).author_name, topic.author_name)
    topic = Topic.find(2)
    assert_equal(topics(:second).author_name, topic.author_name)

    topic = Topic.new
    topic.title = "New Topic"
    assert_equal(nil, topic.id)
    assert_nothing_raised { topic.save! }
    id = topic.id

    topicReloaded = Topic.find(id)
    assert_equal("New Topic", topicReloaded.title)
  end

  def test_customized_primary_key_auto_assigns_on_save
    Keyboard.delete_all
    keyboard = Keyboard.new(:name => 'HHKB')
    assert_nothing_raised { keyboard.save! }
    assert_equal keyboard.id, Keyboard.find_by_name('HHKB').id
  end

  def test_customized_primary_key_can_be_get_before_saving
    keyboard = Keyboard.new
    assert_nil keyboard.id
    assert_nothing_raised { assert_nil keyboard.key_number }
  end

  def test_customized_string_primary_key_settable_before_save
    subscriber = Subscriber.new
    assert_nothing_raised { subscriber.id = 'webster123' }
    assert_equal 'webster123', subscriber.id
    assert_equal 'webster123', subscriber.nick
  end

  def test_string_key
    subscriber = Subscriber.find(subscribers(:first).nick)
    assert_equal(subscribers(:first).name, subscriber.name)
    subscriber = Subscriber.find(subscribers(:second).nick)
    assert_equal(subscribers(:second).name, subscriber.name)

    subscriber = Subscriber.new
    subscriber.id = "jdoe"
    assert_equal("jdoe", subscriber.id)
    subscriber.name = "John Doe"
    assert_nothing_raised { subscriber.save! }
    assert_equal("jdoe", subscriber.id)

    subscriberReloaded = Subscriber.find("jdoe")
    assert_equal("John Doe", subscriberReloaded.name)
  end

  def test_find_with_more_than_one_string_key
    assert_equal 2, Subscriber.find(subscribers(:first).nick, subscribers(:second).nick).length
  end
  
  def test_primary_key_prefix
    ActiveRecord::Base.primary_key_prefix_type = :table_name
    Topic.reset_primary_key
    assert_equal "topicid", Topic.primary_key

    ActiveRecord::Base.primary_key_prefix_type = :table_name_with_underscore
    Topic.reset_primary_key
    assert_equal "topic_id", Topic.primary_key

    ActiveRecord::Base.primary_key_prefix_type = nil
    Topic.reset_primary_key
    assert_equal "id", Topic.primary_key
  end
end
