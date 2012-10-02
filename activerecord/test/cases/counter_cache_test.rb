require 'cases/helper'
require 'models/topic'
require 'models/car'
require 'models/wheel'
require 'models/engine'
require 'models/reply'
require 'models/category'
require 'models/categorization'
require 'models/dog'
require 'models/dog_lover'
require 'models/person'
require 'models/friendship'
require 'models/subscriber'
require 'models/subscription'
require 'models/book'

class CounterCacheTest < ActiveRecord::TestCase
  fixtures :topics, :categories, :categorizations, :cars, :dogs, :dog_lovers, :people, :friendships, :subscribers, :subscriptions, :books

  class ::SpecialTopic < ::Topic
    has_many :special_replies, :foreign_key => 'parent_id'
  end

  class ::SpecialReply < ::Reply
    belongs_to :special_topic, :foreign_key => 'parent_id', :counter_cache => 'replies_count'
  end

  setup do
    @topic = Topic.find(1)
  end

  test "increment counter" do
    assert_difference '@topic.reload.replies_count' do
      Topic.increment_counter(:replies_count, @topic.id)
    end
  end

  test "decrement counter" do
    assert_difference '@topic.reload.replies_count', -1 do
      Topic.decrement_counter(:replies_count, @topic.id)
    end
  end

  test "reset counters" do
    # throw the count off by 1
    Topic.increment_counter(:replies_count, @topic.id)

    # check that it gets reset
    assert_difference '@topic.reload.replies_count', -1 do
      Topic.reset_counters(@topic.id, :replies)
    end
  end

  test "reset counters with string argument" do
    Topic.increment_counter('replies_count', @topic.id)

    assert_difference '@topic.reload.replies_count', -1 do
      Topic.reset_counters(@topic.id, 'replies')
    end
  end

  test "reset counters with modularized and camelized classnames" do
    special = SpecialTopic.create!(:title => 'Special')
    SpecialTopic.increment_counter(:replies_count, special.id)

    assert_difference 'special.reload.replies_count', -1 do
      SpecialTopic.reset_counters(special.id, :special_replies)
    end
  end

  test "reset counter with belongs_to which has class_name" do
    car = cars(:honda)
    assert_nothing_raised do
      Car.reset_counters(car.id, :engines)
    end
    assert_nothing_raised do
      Car.reset_counters(car.id, :wheels)
    end
  end

  test "reset the right counter if two have the same class_name" do
    david = dog_lovers(:david)

    DogLover.increment_counter(:bred_dogs_count, david.id)
    DogLover.increment_counter(:trained_dogs_count, david.id)

    assert_difference 'david.reload.bred_dogs_count', -1 do
      DogLover.reset_counters(david.id, :bred_dogs)
    end
    assert_difference 'david.reload.trained_dogs_count', -1 do
      DogLover.reset_counters(david.id, :trained_dogs)
    end
  end

  test "update counter with initial null value" do
    category = categories(:general)
    assert_equal 2, category.categorizations.count
    assert_nil category.categorizations_count

    Category.update_counters(category.id, :categorizations_count => category.categorizations.count)
    assert_equal 2, category.reload.categorizations_count
  end

  test "update counter for decrement" do
    assert_difference '@topic.reload.replies_count', -3 do
      Topic.update_counters(@topic.id, :replies_count => -3)
    end
  end

  test "update counters of multiple records" do
    t1, t2 = topics(:first, :second)

    assert_difference ['t1.reload.replies_count', 't2.reload.replies_count'], 2 do
      Topic.update_counters([t1.id, t2.id], :replies_count => 2)
    end
  end

  test "reset the right counter if two have the same foreign key" do
    michael = people(:michael)
    assert_nothing_raised(ActiveRecord::StatementInvalid) do
      Person.reset_counters(michael.id, :followers)
    end
  end

  test "reset counter of has_many :through association" do
    subscriber = subscribers('second')
    Subscriber.reset_counters(subscriber.id, 'books')
    Subscriber.increment_counter('books_count', subscriber.id)

    assert_difference 'subscriber.reload.books_count', -1 do
      Subscriber.reset_counters(subscriber.id, 'books')
    end
  end
end
