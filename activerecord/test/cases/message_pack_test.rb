# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/binary"
require "models/comment"
require "models/post"
require "active_support/message_pack"
require "active_record/message_pack"

class ActiveRecordMessagePackTest < ActiveRecord::TestCase
  fixtures :posts, :comments, :authors, :author_addresses

  test "enshrines type IDs" do
    expected = {
      119 => ActiveModel::Type::Binary::Data,
      120 => ActiveRecord::Base,
    }

    factory = ::MessagePack::Factory.new
    ActiveRecord::MessagePack::Extensions.install(factory)
    actual = factory.registered_types.to_h do |entry|
      [entry[:type], entry[:class]]
    end

    assert_equal expected, actual
  end

  test "roundtrips record and cached associations" do
    post = Post.create!(title: "A Title", body: "A body.")
    post.create_author!(name: "An Author")
    post.comments.create!(body: "A comment.")
    post.comments.create!(body: "Another comment.", author: post.author)
    post.comments.load

    assert_no_queries do
      roundtripped_post = roundtrip(post)

      assert_equal post, roundtripped_post
      assert_equal post.author, roundtripped_post.author
      assert_equal post.comments.to_a, roundtripped_post.comments.to_a
      assert_equal post.comments.map(&:author), roundtripped_post.comments.map(&:author)

      assert_same roundtripped_post, roundtripped_post.comments[0].post
      assert_same roundtripped_post, roundtripped_post.comments[1].post
      assert_same roundtripped_post.author, roundtripped_post.comments[1].author
    end
  end

  test "roundtrips new_record? status" do
    post = Post.new(title: "A Title", body: "A body.")
    post.create_author!(name: "An Author")

    assert_no_queries do
      roundtripped_post = roundtrip(post)

      assert_equal post.attributes, roundtripped_post.attributes
      assert_equal post.new_record?, roundtripped_post.new_record?
      assert_equal post.author, roundtripped_post.author
      assert_equal post.author.new_record?, roundtripped_post.author.new_record?
    end
  end

  test "roundtrips binary attribute" do
    binary = Binary.new(data: Marshal.dump("data"))
    assert_equal binary.attributes, roundtrip(binary).attributes
  end

  test "raises ActiveSupport::MessagePack::MissingClassError if record class no longer exists" do
    klass = Class.new(Post)
    def klass.name; "SomeLegacyClass"; end
    dumped = serializer.dump(klass.new(title: "A Title", body: "A body."))

    assert_raises ActiveSupport::MessagePack::MissingClassError do
      serializer.load(dumped)
    end
  end

  private
    def serializer
      @serializer ||= ::MessagePack::Factory.new.tap do |factory|
        ActiveRecord::MessagePack::Extensions.install(factory)
        ActiveSupport::MessagePack::Extensions.install(factory)
        ActiveSupport::MessagePack::Extensions.install_unregistered_type_error(factory)
      end
    end

    def roundtrip(input)
      serializer.load(serializer.dump(input))
    end
end
