# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/comment"

class AliasAssociationTest < ActiveRecord::TestCase
  setup do
    @post = Post.create(title: "hello world", body: "I'm going to test alias association feature")
    @comment = @post.comments.create(body: "what a wonderful feature")
  end

  def test_raises_error_when_aliasing_a_non_existing_association
    assert_raises(ArgumentError, match: "Can't alias a non-existing `actually_i_do_not_exist` association") do
      Class.new(ActiveRecord::Base) do
        alias_association :new_shiny_name, :actually_i_do_not_exist
      end
    end
  end

  def test_has_many_association_reader
    assert_equal [@comment], @post.opinions.to_a
  end

  def test_has_many_association_writer
    post = Post.new
    comment1 = Comment.new
    post.opinions = [comment1]
    comment2 = Comment.new
    post.opinions << comment2

    assert_equal [comment1, comment2], post.comments
  end

  def test_belongs_to_association_reader
    assert_equal @post, @comment.subject
  end

  def test_belongs_to_association_writer
    comment = Comment.new
    post = Post.new
    comment.subject = post
    assert_equal post, comment.post
  end

  def test_belongs_to_build_association_record
    comment = Comment.new
    comment.build_subject(title: "i was built", body: "I'm glad this is working")
    assert_equal "i was built", comment.post.title
  end

  def test_belongs_to_alias_in_where
    comments = Comment.where(subject: @post).to_a
    assert_equal [@comment], comments
  end

  def test_has_many_alias_in_where
    post = Post.where(opinions: @comment).take
    assert_equal @post, post
  end

  def test_includes_has_many_alias
    post = Post.where(id: @post.id).includes(:opinions).take
    comments = assert_no_queries { post.comments.to_a }
    assert_equal [@comment], comments
  end

  def test_includes_belongs_to_alias
    comment = Comment.where(id: @comment.id).includes(:subject).take
    post = assert_no_queries { comment.post }
    assert_equal @post, post
  end

  def test_belong_to_aliased_change_tracking_methods
    assert_not_predicate @comment, :subject_changed?
    assert_predicate @comment, :subject_previously_changed?
  end
end
