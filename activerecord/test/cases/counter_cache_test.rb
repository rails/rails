# frozen_string_literal: true

require "cases/helper"
require "models/topic"
require "models/car"
require "models/aircraft"
require "models/wheel"
require "models/engine"
require "models/reply"
require "models/category"
require "models/categorization"
require "models/dog"
require "models/dog_lover"
require "models/person"
require "models/friendship"
require "models/subscriber"
require "models/subscription"
require "models/book"
require "active_support/core_ext/enumerable"

class CounterCacheTest < ActiveRecord::TestCase
  fixtures :topics, :categories, :categorizations, :cars, :dogs, :dog_lovers, :people, :friendships, :subscribers, :subscriptions, :books

  class ::SpecialTopic < ::Topic
    has_many :special_replies, foreign_key: "parent_id"
    has_many :lightweight_special_replies, -> { select("topics.id, topics.title") }, foreign_key: "parent_id", class_name: "SpecialReply"
  end

  class ::SpecialReply < ::Reply
    belongs_to :special_topic, foreign_key: "parent_id", counter_cache: "replies_count"
  end

  setup do
    @topic = Topic.find(1)
  end

  test "increment counter" do
    assert_difference "@topic.reload.replies_count" do
      Topic.increment_counter(:replies_count, @topic.id)
    end
  end

  test "decrement counter" do
    assert_difference "@topic.reload.replies_count", -1 do
      Topic.decrement_counter(:replies_count, @topic.id)
    end
  end

  test "reset counters" do
    # throw the count off by 1
    Topic.increment_counter(:replies_count, @topic.id)

    # check that it gets reset
    assert_difference "@topic.reload.replies_count", -1 do
      Topic.reset_counters(@topic.id, :replies)
    end
  end

  test "reset counters by counter name" do
    # throw the count off by 1
    Topic.increment_counter(:replies_count, @topic.id)

    # check that it gets reset
    assert_difference "@topic.reload.replies_count", -1 do
      Topic.reset_counters(@topic.id, :replies_count)
    end
  end

  test "reset multiple counters" do
    Topic.update_counters @topic.id, replies_count: 1, unique_replies_count: 1
    assert_difference ["@topic.reload.replies_count", "@topic.reload.unique_replies_count"], -1 do
      Topic.reset_counters(@topic.id, :replies, :unique_replies)
    end
  end

  test "reset counters with string argument" do
    Topic.increment_counter("replies_count", @topic.id)

    assert_difference "@topic.reload.replies_count", -1 do
      Topic.reset_counters(@topic.id, "replies")
    end
  end

  test "reset counters with modularized and camelized classnames" do
    special = SpecialTopic.create!(title: "Special")
    SpecialTopic.increment_counter(:replies_count, special.id)

    assert_difference "special.reload.replies_count", -1 do
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

    assert_difference "david.reload.bred_dogs_count", -1 do
      DogLover.reset_counters(david.id, :bred_dogs)
    end
    assert_difference "david.reload.trained_dogs_count", -1 do
      DogLover.reset_counters(david.id, :trained_dogs)
    end
  end

  test "update counter with initial null value" do
    category = categories(:general)
    assert_equal 2, category.categorizations.count
    assert_nil category.categorizations_count

    Category.update_counters(category.id, categorizations_count: category.categorizations.count)
    assert_equal 2, category.reload.categorizations_count
  end

  test "update counter for decrement" do
    assert_difference "@topic.reload.replies_count", -3 do
      Topic.update_counters(@topic.id, replies_count: -3)
    end
  end

  test "update counters of multiple records" do
    t1, t2 = topics(:first, :second)

    assert_difference ["t1.reload.replies_count", "t2.reload.replies_count"], 2 do
      Topic.update_counters([t1.id, t2.id], replies_count: 2)
    end
  end

  test "update multiple counters" do
    assert_difference ["@topic.reload.replies_count", "@topic.reload.unique_replies_count"], 2 do
      Topic.update_counters @topic.id, replies_count: 2, unique_replies_count: 2
    end
  end

  test "update other counters on parent destroy" do
    david, joanna = dog_lovers(:david, :joanna)
    _ = joanna # squelch a warning

    assert_difference "joanna.reload.dogs_count", -1 do
      david.destroy
    end
  end

  test "reset the right counter if two have the same foreign key" do
    michael = people(:michael)
    assert_nothing_raised do
      Person.reset_counters(michael.id, :friends_too)
    end
  end

  test "reset counter of has_many :through association" do
    subscriber = subscribers("second")
    Subscriber.reset_counters(subscriber.id, "books")
    Subscriber.increment_counter("books_count", subscriber.id)

    assert_difference "subscriber.reload.books_count", -1 do
      Subscriber.reset_counters(subscriber.id, "books")
    end
  end

  test "the passed symbol needs to be an association name or counter name" do
    e = assert_raises(ArgumentError) do
      Topic.reset_counters(@topic.id, :undefined_count)
    end
    assert_equal "'Topic' has no association called 'undefined_count'", e.message
  end

  test "reset counter works with select declared on association" do
    special = SpecialTopic.create!(title: "Special")
    SpecialTopic.increment_counter(:replies_count, special.id)

    assert_difference "special.reload.replies_count", -1 do
      SpecialTopic.reset_counters(special.id, :lightweight_special_replies)
    end
  end

  test "counters are updated both in memory and in the database on create" do
    car = Car.new(engines_count: 0)
    car.engines = [Engine.new, Engine.new]
    car.save!

    assert_equal 2, car.engines_count
    assert_equal 2, car.reload.engines_count
  end

  test "counter caches are updated in memory when the default value is nil" do
    car = Car.new(engines_count: nil)
    car.engines = [Engine.new, Engine.new]
    car.save!

    assert_equal 2, car.engines_count
    assert_equal 2, car.reload.engines_count
  end

  test "update counters in a polymorphic relationship" do
    aircraft = Aircraft.create!

    assert_difference "aircraft.reload.wheels_count" do
      aircraft.wheels << Wheel.create!
    end

    assert_difference "aircraft.reload.wheels_count", -1 do
      aircraft.wheels.first.destroy
    end
  end

  test "update counters doesn't touch timestamps by default" do
    @topic.update_column :updated_at, 5.minutes.ago
    previously_updated_at = @topic.updated_at

    Topic.update_counters(@topic.id, replies_count: -1)

    assert_equal previously_updated_at, @topic.updated_at
  end

  test "update counters doesn't touch timestamps with touch: []" do
    @topic.update_column :updated_at, 5.minutes.ago
    previously_updated_at = @topic.updated_at

    Topic.update_counters(@topic.id, replies_count: -1, touch: [])

    assert_equal previously_updated_at, @topic.updated_at
  end

  test "update counters with touch: true" do
    assert_touching @topic, :updated_at do
      Topic.update_counters(@topic.id, replies_count: -1, touch: true)
    end
  end

  test "update counters of multiple records with touch: true" do
    t1, t2 = topics(:first, :second)

    assert_touching t1, :updated_at do
      assert_difference ["t1.reload.replies_count", "t2.reload.replies_count"], 2 do
        Topic.update_counters([t1.id, t2.id], replies_count: 2, touch: true)
      end
    end
  end

  test "update multiple counters with touch: true" do
    assert_touching @topic, :updated_at do
      Topic.update_counters(@topic.id, replies_count: 2, unique_replies_count: 2, touch: true)
    end
  end

  test "reset counters with touch: true" do
    assert_touching @topic, :updated_at do
      Topic.reset_counters(@topic.id, :replies, touch: true)
    end
  end

  test "reset multiple counters with touch: true" do
    assert_touching @topic, :updated_at do
      Topic.update_counters(@topic.id, replies_count: 1, unique_replies_count: 1)
      Topic.reset_counters(@topic.id, :replies, :unique_replies, touch: { time: Time.now.utc })
    end
  end

  test "increment counters with touch: true" do
    assert_touching @topic, :updated_at do
      Topic.increment_counter(:replies_count, @topic.id, touch: true)
    end
  end

  test "decrement counters with touch: true" do
    assert_touching @topic, :updated_at do
      Topic.decrement_counter(:replies_count, @topic.id, touch: true)
    end
  end

  test "update counters with touch: :written_on" do
    assert_touching @topic, :updated_at, :written_on do
      Topic.update_counters(@topic.id, replies_count: -1, touch: :written_on)
    end
  end

  test "update multiple counters with touch: :written_on" do
    assert_touching @topic, :updated_at, :written_on do
      Topic.update_counters(@topic.id, replies_count: 2, unique_replies_count: 2, touch: :written_on)
    end
  end

  test "reset counters with touch: :written_on" do
    assert_touching @topic, :updated_at, :written_on do
      Topic.reset_counters(@topic.id, :replies, touch: :written_on)
    end
  end

  test "reset multiple counters with touch: :written_on" do
    assert_touching @topic, :updated_at, :written_on do
      Topic.update_counters(@topic.id, replies_count: 1, unique_replies_count: 1)
      Topic.reset_counters(@topic.id, :replies, :unique_replies, touch: :written_on)
    end
  end

  test "increment counters with touch: :written_on" do
    assert_touching @topic, :updated_at, :written_on do
      Topic.increment_counter(:replies_count, @topic.id, touch: :written_on)
    end
  end

  test "decrement counters with touch: :written_on" do
    assert_touching @topic, :updated_at, :written_on do
      Topic.decrement_counter(:replies_count, @topic.id, touch: :written_on)
    end
  end

  test "update counters with touch: %i( updated_at written_on )" do
    assert_touching @topic, :updated_at, :written_on do
      Topic.update_counters(@topic.id, replies_count: -1, touch: %i( updated_at written_on ))
    end
  end

  test "update multiple counters with touch: %i( updated_at written_on )" do
    assert_touching @topic, :updated_at, :written_on do
      Topic.update_counters(@topic.id, replies_count: 2, unique_replies_count: 2, touch: %i( updated_at written_on ))
    end
  end

  test "reset counters with touch: %i( updated_at written_on )" do
    assert_touching @topic, :updated_at, :written_on do
      Topic.reset_counters(@topic.id, :replies, touch: %i( updated_at written_on ))
    end
  end

  test "reset multiple counters with touch: %i( updated_at written_on )" do
    assert_touching @topic, :updated_at, :written_on do
      Topic.update_counters(@topic.id, replies_count: 1, unique_replies_count: 1)
      Topic.reset_counters(@topic.id, :replies, :unique_replies, touch: %i( updated_at written_on ))
    end
  end

  test "increment counters with touch: %i( updated_at written_on )" do
    assert_touching @topic, :updated_at, :written_on do
      Topic.increment_counter(:replies_count, @topic.id, touch: %i( updated_at written_on ))
    end
  end

  test "decrement counters with touch: %i( updated_at written_on )" do
    assert_touching @topic, :updated_at, :written_on do
      Topic.decrement_counter(:replies_count, @topic.id, touch: %i( updated_at written_on ))
    end
  end

  private
    def assert_touching(record, *attributes)
      record.update_columns attributes.index_with(5.minutes.ago)
      touch_times = attributes.index_with { |attr| record.public_send(attr) }

      yield

      touch_times.each do |attr, previous_touch_time|
        assert_operator previous_touch_time, :<, record.reload.public_send(attr)
      end
    end
end
