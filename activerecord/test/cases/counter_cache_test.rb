# frozen_string_literal: true

require "cases/helper"
require "models/topic"
require "models/bulb"
require "models/person"
require "models/car"
require "models/aircraft"
require "models/wheel"
require "models/engine"
require "models/tire"
require "models/reply"
require "models/category"
require "models/categorization"
require "models/dog"
require "models/dog_lover"
require "models/friendship"
require "models/subscriber"
require "models/subscription"
require "models/book"
require "models/scoped_counter_cache_topic"
require "models/scoped_counter_cache_child"
require "models/cpk"
require "models/post"
require "active_support/core_ext/enumerable"
require "active_support/testing/ractors_assertions"

class CounterCacheTest < ActiveRecord::TestCase
  include ActiveSupport::Testing::RactorsAssertions

  fixtures :topics, :categories, :categorizations, :cars, :dogs, :dog_lovers, :people, :friendships, :subscribers, :subscriptions, :books,
    :cpk_orders, :cpk_books

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

  test "update counters uses only all-query default scopes" do
    assert_difference -> { @topic.reload.replies_count } do
      ScopedCounterCacheTopic.update_counters(@topic.id, replies_count: 1)
    end
  end

  test "reset counters uses only all-query default scopes" do
    @topic.update_columns(replies_count: 0)
    ScopedCounterCacheTopic.reset_counters(@topic.id, :replies)

    assert_equal 1, @topic.reload.replies_count
  end

  test "belongs_to counter cache uses only all-query default scopes" do
    assert_difference -> { @topic.reload.replies_count } do
      ScopedCounterCacheChild.create!(title: "Counter cache child", parent_id: @topic.id, approved: true)
    end
  end

  test "increment counter" do
    assert_difference "@topic.reload.replies_count" do
      Topic.increment_counter(:replies_count, @topic.id)
    end
  end

  test "increment counter by specific amount" do
    assert_difference -> { @topic.reload.replies_count }, +2 do
      Topic.increment_counter(:replies_count, @topic.id, by: 2)
    end
  end

  test "increment counter for cpk model" do
    order = Cpk::Order.first
    assert_difference -> { order.reload.books_count } do
      Cpk::Order.increment_counter(:books_count, order.id)
    end
  end

  test "increment counter for multiple cpk model records" do
    order1, order2 = Cpk::Order.first(2)
    assert_difference [-> { order1.reload.books_count }, -> { order2.reload.books_count }] do
      Cpk::Order.increment_counter(:books_count, [order1.id, order2.id])
    end
  end

  test "decrement counter" do
    assert_difference "@topic.reload.replies_count", -1 do
      Topic.decrement_counter(:replies_count, @topic.id)
    end
  end

  test "decrement counter by specific amount" do
    assert_difference "@topic.reload.replies_count", -2 do
      Topic.decrement_counter(:replies_count, @topic.id, by: 2)
    end
  end

  test "decrement counter for cpk model" do
    order = Cpk::Order.first
    assert_difference -> { order.reload.books_count }, -1 do
      Cpk::Order.decrement_counter(:books_count, order.id)
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

  test "reset counters for multiple records" do
    t1, t2 = topics(:first, :second)
    Topic.increment_counter(:replies_count, [t1.id, t2.id])

    assert_difference ["t1.reload.replies_count", "t2.reload.replies_count"], -1 do
      Topic.reset_counters([t1.id, t2.id], :replies_count)
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

  test "reset counters with string id" do
    assert @topic.replies_count > 0, "Must have replies"
    Topic.increment_counter("replies_count", @topic.id)

    assert_difference "@topic.reload.replies_count", -1 do
      Topic.reset_counters(@topic.id.to_s, :replies)
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

  test "reset counter skips query for correct counter" do
    Topic.reset_counters(@topic.id, :replies_count)

    # SELECT "topics".* FROM "topics" WHERE "topics"."id" = ? LIMIT ?
    # SELECT COUNT(*) FROM "topics" WHERE "topics"."type" IN (?, ?, ?, ?, ?) AND "topics"."parent_id" = ?
    assert_queries_count(2) do
      Topic.reset_counters(@topic.id, :replies_count)
    end
  end

  test "reset counter performs query for correct counter with touch: true" do
    Topic.reset_counters(@topic.id, :replies_count)

    # SELECT COUNT(*) FROM "topics" WHERE "topics"."type" IN (?, ?, ?, ?, ?) AND "topics"."parent_id" = ?
    # UPDATE "topics" SET "updated_at" = ? WHERE "topics"."id" = ?
    assert_queries_count(2) do
      Topic.reset_counters(@topic.id, :replies_count, touch: true)
    end
  end

  test "reset counters for cpk model" do
    order = Cpk::Order.first
    # throw the count off by 1
    Cpk::Order.increment_counter(:books_count, order.id)

    # check that it gets reset
    assert_difference -> { order.reload.books_count }, -1 do
      Cpk::Order.reset_counters(order.id, :books)
    end
  end

  test "belongs_to counter cache is maintained on create/update/destroy for cpk model" do
    order1 = Cpk::Order.create!(id: [9999, 10001], status: "open")
    order2 = Cpk::Order.create!(id: [9999, 10002], status: "open")

    book = nil
    assert_difference -> { order1.reload.books_count }, 1 do
      book = Cpk::Book.create!(id: [9999, 10001], title: "Book", order: order1)
    end

    assert_difference(
      { -> { order1.reload.books_count } => -1,
        -> { order2.reload.books_count } => 1 }
    ) do
      book.update!(order: order2)
    end

    assert_difference -> { order2.reload.books_count }, -1 do
      book.destroy!
    end
  end

  test "belongs_to counter cache is maintained when composite foreign key is manually set" do
    author = Cpk::Author.create!(name: "author")
    book = Cpk::Book.create!(id: [author.id, 9999], title: "Book")
    assert_nil book.shop_id
    assert_nil book.order_id

    order = Cpk::Order.create!(id: [1, 200], status: "open")

    assert_difference -> { order.reload.books_count }, 1 do
      book.update!(order: order)
    end
  end

  test "reset counters for cpk model with string ids" do
    order = cpk_orders(:cpk_book_order_1)
    assert order.books_count > 0, "Must have books"

    Cpk::Order.increment_counter(:books_count, order.id)

    # check that it gets reset
    assert_difference -> { order.reload.books_count }, -1 do
      string_id = order.id.map(&:to_s)
      Cpk::Order.reset_counters(string_id, :books)
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

  test "update counter for decrement for cpk model" do
    order = Cpk::Order.first
    assert_difference -> { order.reload.books_count }, -3 do
      Cpk::Order.update_counters(order.id, books_count: -3)
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

  test "removing association updates counter" do
    michael = people(:michael)
    car = cars(:honda)

    assert_difference -> { michael.reload.cars_count }, -1 do
      car.destroy
    end
  end

  test "polymorphic counter cache is decremented through an aliased foreign type" do
    model = Class.new(ActiveRecord::Base) do
      self.table_name = "comments"

      def self.name; "AliasedTypeComment"; end

      alias_attribute :target_kind, :author_type
      belongs_to :target,
        polymorphic: true,
        foreign_key: :author_id,
        foreign_type: :target_kind,
        counter_cache: :legacy_comments_count,
        optional: true
    end
    target = Post.create!(title: "Aliased type", body: "Aliased type")
    target.update_column(:legacy_comments_count, 1)
    model.create!(post_id: target.id, body: "Aliased type comment").update_columns(
      author_id: target.id,
      author_type: Post.polymorphic_name
    )
    comment = model.find_by!(body: "Aliased type comment")

    comment.author_id = nil
    comment.save!

    assert_equal 0, target.reload.legacy_comments_count
  end

  test "counter cache of the previous target is decremented through a foreign key alias remapped by a subclass" do
    model = Class.new(ActiveRecord::Base) do
      self.table_name = "comments"
      self.inheritance_column = nil

      def self.name; "AliasedKeyComment"; end

      alias_attribute :post_key, :post_id
      belongs_to :keyed_post,
        class_name: "Post",
        foreign_key: :post_key,
        counter_cache: :legacy_comments_count,
        optional: true
    end
    remapped_model = Class.new(model) do
      def self.name; "RemappedKeyComment"; end

      alias_attribute :post_key, :author_id
    end
    decoy = Post.create!(title: "Decoy", body: "Decoy")
    original = Post.create!(title: "Original", body: "Original")
    replacement = Post.create!(title: "Replacement", body: "Replacement")
    comment = remapped_model.create!(post_id: decoy.id, keyed_post: original, body: "Counted comment")
    assert_equal 1, original.reload.legacy_comments_count

    comment.update!(keyed_post: replacement)

    assert_equal 0, original.reload.legacy_comments_count
    assert_equal 1, replacement.reload.legacy_comments_count
    assert_equal 0, decoy.reload.legacy_comments_count
  end

  test "counter cache is not decremented through a partial composite foreign key" do
    model = Class.new(ActiveRecord::Base) do
      self.table_name = "sponsors"

      def self.name; "CompositeCounterSponsor"; end

      belongs_to :post,
        foreign_key: [:club_id, :sponsorable_id],
        primary_key: [:author_id, :id],
        counter_cache: :legacy_comments_count,
        optional: true
    end
    unrelated = Post.create!(author_id: nil, title: "Unrelated", body: "Unrelated")
    post = Post.create!(author_id: 9_000_001, title: "Composite counter", body: "Composite counter")
    reference = model.create!(club_id: nil, sponsorable_id: unrelated.id)
    unrelated.update_column(:legacy_comments_count, 1)

    reference.update!(club_id: post.author_id, sponsorable_id: post.id)

    assert_equal 1, unrelated.reload.legacy_comments_count
    assert_equal 1, post.reload.legacy_comments_count
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

  test "counter_cache_column?" do
    assert Person.counter_cache_column?("cars_count")
    assert_not Car.counter_cache_column?("cars_count")
  end

  test "inactive counter cache" do
    car = Car.new
    car.bulbs = [Bulb.new, Bulb.new]
    car.save!

    assert_equal 2, car.bulbs_count
    car.reload

    assert_queries_count(5) do
      assert_equal 2, car.bulbs.size
      assert_equal 2, car.bulbs.count
      assert_not_predicate car.bulbs, :empty?
      assert_predicate car.bulbs, :any?
      assert_not_predicate car.bulbs, :none?
    end
  end

  test "active counter cache" do
    car = Car.new
    car.tires = [Tire.new, Tire.new]
    car.save!

    assert_equal 2, car.custom_tires_count
    car.reload

    assert_no_queries do
      assert_equal 2, car.tires.size
      assert_not_predicate car.tires, :empty?
      assert_predicate car.tires, :any?
      assert_not_predicate car.tires, :none?
    end

    assert_queries_count(1) do
      assert_equal 2, car.tires.count
    end
  end

  test "counter cache configuration is ractor shareable" do
    assert_ractor_shareable SpecialReply.counter_cached_association_names
    assert_ractor_shareable SpecialReply._counter_cache_columns
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
