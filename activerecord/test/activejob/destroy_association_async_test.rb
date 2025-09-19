# frozen_string_literal: true

require "activejob/helper"

require "models/book_destroy_async"
require "models/essay_destroy_async"
require "models/tag"
require "models/tagging"
require "models/author"
require "models/essay"
require "models/category"
require "models/post"
require "models/content"
require "models/destroy_async_parent"
require "models/destroy_async_parent_soft_delete"
require "models/dl_keyed_belongs_to"
require "models/dl_keyed_belongs_to_soft_delete"
require "models/dl_keyed_has_one"
require "models/dl_keyed_join"
require "models/dl_keyed_has_many"
require "models/dl_keyed_has_many_through"
require "models/sharded/blog_post_destroy_async"
require "models/sharded/comment_destroy_async"
require "models/sharded/tag"
require "models/sharded/blog_post"
require "models/sharded/blog_post_tag"
require "models/sharded/blog"
require "models/cpk/book_destroy_async"
require "models/cpk/chapter_destroy_async"

class DestroyAssociationAsyncTest < ActiveRecord::TestCase
  include ActiveJob::TestHelper

  test "destroying a record destroys the has_many :through records using a job" do
    tag = Tag.create!(name: "Der be treasure")
    tag2 = Tag.create!(name: "Der be rum")
    book = BookDestroyAsync.create!
    book.tags << [tag, tag2]
    book.save!

    assert_enqueued_jobs 1, only: ActiveRecord::DestroyAssociationAsyncJob do
      book.destroy
    end

    assert_difference -> { Tag.count }, -2 do
      perform_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
    end
  ensure
    Tag.delete_all
    BookDestroyAsync.delete_all
  end

  test "destroying a record destroys has_many :through associated by composite primary key using a job" do
    blog = Sharded::Blog.create!
    blog_post = Sharded::BlogPostDestroyAsync.create!(blog_id: blog.id)

    tag1 = Sharded::Tag.create!(name: "Short Read", blog_id: blog.id)
    tag2 = Sharded::Tag.create!(name: "Science", blog_id: blog.id)

    blog_post.tags << [tag1, tag2]

    blog_post.save!

    assert_enqueued_jobs 1, only: ActiveRecord::DestroyAssociationAsyncJob do
      blog_post.destroy
    end

    sql = capture_sql do
      assert_difference -> { Sharded::Tag.count }, -2 do
        perform_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
      end
    end

    delete_sqls = sql.select { |sql| sql.start_with?("DELETE") }
    assert_equal 2, delete_sqls.count

    delete_sqls.each do |sql|
      assert_match(/#{Regexp.escape(quote_table_name("sharded_tags.blog_id"))} =/, sql)
    end
  ensure
    Sharded::Tag.delete_all
    Sharded::BlogPostDestroyAsync.delete_all
    Sharded::Blog.delete_all
  end

  test "destroying a scoped has_many through only deletes within the scope deleted" do
    tag = Tag.create!(name: "Der be treasure")
    tag2 = Tag.create!(name: "Der be rum")
    parent = BookDestroyAsyncWithScopedTags.create!
    parent.tags << [tag, tag2]
    parent.save!

    parent.reload # force the association to be reloaded

    parent.destroy

    assert_difference -> { Tag.count }, -1 do
      perform_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
    end
    assert_raises ActiveRecord::RecordNotFound do
      tag2.reload
    end
    assert tag.reload
  ensure
    Tag.delete_all
    Tagging.delete_all
    BookDestroyAsyncWithScopedTags.delete_all
  end

  test "enqueues the has_many through to be deleted with custom primary key" do
    dl_keyed_has_many = DlKeyedHasManyThrough.create!
    dl_keyed_has_many2 = DlKeyedHasManyThrough.create!
    parent = DestroyAsyncParent.create!
    parent.dl_keyed_has_many_through << [dl_keyed_has_many2, dl_keyed_has_many]
    parent.save!
    parent.destroy

    assert_difference -> { DlKeyedJoin.count }, -2 do
      assert_difference -> { DlKeyedHasManyThrough.count }, -2 do
        perform_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
      end
    end
  ensure
    DlKeyedHasManyThrough.delete_all
    DestroyAsyncParent.delete_all
    DlKeyedJoin.delete_all
  end

  test "enqueues multiple jobs if count of dependent records to destroy is greater than batch size" do
    ActiveRecord::Base.destroy_association_async_batch_size = 1

    tag = Tag.create!(name: "Der be treasure")
    tag2 = Tag.create!(name: "Der be rum")
    book = BookDestroyAsync.create!
    book.tags << [tag, tag2]
    book.save!

    job_1_args = ->(job_args) { job_args.first[:association_ids] == [tag.id] }
    job_2_args = ->(job_args) { job_args.first[:association_ids] == [tag2.id] }

    assert_enqueued_with(job: ActiveRecord::DestroyAssociationAsyncJob, args: job_1_args) do
      assert_enqueued_with(job: ActiveRecord::DestroyAssociationAsyncJob, args: job_2_args) do
        book.destroy
      end
    end

    assert_difference -> { Tag.count }, -2 do
      perform_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
    end
  ensure
    Tag.delete_all
    BookDestroyAsync.delete_all
    ActiveRecord::Base.destroy_association_async_batch_size = nil
  end

  test "belongs to" do
    essay = EssayDestroyAsync.create!(name: "Der be treasure")
    book = BookDestroyAsync.create!(name: "Arr, matey!")
    essay.book = book
    essay.save!
    essay.destroy

    assert_difference -> { BookDestroyAsync.count }, -1 do
      perform_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
    end
  ensure
    EssayDestroyAsync.delete_all
    BookDestroyAsync.delete_all
  end

  test "belongs to associated by composite primary key" do
    blog = Sharded::Blog.create!
    blog_post = Sharded::BlogPostDestroyAsync.create!(blog_id: blog.id)
    comment = Sharded::CommentDestroyAsync.create!(body: "Great post! :clap:")

    comment.blog_post = blog_post
    comment.save!

    assert_enqueued_jobs 1, only: ActiveRecord::DestroyAssociationAsyncJob do
      comment.destroy
    end

    sql = capture_sql do
      assert_difference -> { Sharded::BlogPostDestroyAsync.count }, -1 do
        perform_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
      end
    end

    delete_sqls = sql.select { |sql| sql.start_with?("DELETE") }
    assert_equal 1, delete_sqls.count
    assert_match(/#{Regexp.escape(quote_table_name("sharded_blog_posts.blog_id"))} =/, delete_sqls.first)
  ensure
    Sharded::BlogPostDestroyAsync.delete_all
    Sharded::CommentDestroyAsync.delete_all
    Sharded::Blog.delete_all
  end

  test "enqueues belongs_to to be deleted with custom primary key" do
    belongs = DlKeyedBelongsTo.create!
    parent = DestroyAsyncParent.create!
    belongs.destroy_async_parent = parent
    belongs.save!
    belongs.destroy

    assert_difference -> { DestroyAsyncParent.count }, -1 do
      perform_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
    end
  ensure
    DlKeyedBelongsTo.delete_all
    DestroyAsyncParent.delete_all
  end

  test "polymorphic belongs_to" do
    writer = Author.create(name: "David")
    essay = EssayDestroyAsync.create!(name: "Der be treasure", writer: writer)

    essay.destroy

    assert_difference -> { Author.count }, -1 do
      perform_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
    end
  ensure
    EssayDestroyAsync.delete_all
    Author.delete_all
  end

  test "has_one" do
    content = Content.create(title: "hello")
    book = BookDestroyAsync.create!(name: "Arr, matey!")
    book.content = content
    book.save!
    book.destroy

    assert_difference -> { Content.count }, -1 do
      perform_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
    end
  ensure
    Content.delete_all
    BookDestroyAsync.delete_all
  end


  test "enqueues has_one to be deleted with custom primary key" do
    child = DlKeyedHasOne.create!
    parent = DestroyAsyncParent.create!
    parent.dl_keyed_has_one = child
    parent.save!
    parent.destroy

    assert_difference -> { DlKeyedHasOne.count }, -1 do
      perform_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
    end
  ensure
    DlKeyedHasOne.delete_all
    DestroyAsyncParent.delete_all
  end


  test "has_many" do
    essay = EssayDestroyAsync.create!(name: "Der be treasure")
    essay2 = EssayDestroyAsync.create!(name: "Der be rum")
    book = BookDestroyAsync.create!(name: "Arr, matey!")
    book.essays << [essay, essay2]
    book.save!
    book.destroy

    assert_difference -> { EssayDestroyAsync.count }, -2 do
      perform_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
    end
  ensure
    EssayDestroyAsync.delete_all
    BookDestroyAsync.delete_all
  end

  test "has_many with STI parent class destroys all children class records" do
    book = BookDestroyAsync.create!
    LongEssayDestroyAsync.create!(book: book)
    ShortEssayDestroyAsync.create!(book: book)
    book.destroy

    assert_difference -> { EssayDestroyAsync.count }, -2 do
      perform_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
    end
  end

  test "enqueues the has_many to be deleted with custom primary key" do
    dl_keyed_has_many = DlKeyedHasMany.new
    parent = DestroyAsyncParent.create!
    parent.dl_keyed_has_many << [dl_keyed_has_many]

    parent.save!
    parent.destroy

    assert_difference -> { DlKeyedHasMany.count }, -1 do
      perform_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
    end
  ensure
    DlKeyedHasMany.delete_all
    DestroyAsyncParent.delete_all
  end

  test "has_many associated with composite primary key" do
    book = Cpk::BookDestroyAsync.create!(id: [1, 1])
    _chapter1 = book.chapters.create!(id: [1, 1], title: "Chapter 1")
    _chapter2 = book.chapters.create!(id: [1, 2], title: "Chapter 2")

    assert_enqueued_jobs 1, only: ActiveRecord::DestroyAssociationAsyncJob do
      book.destroy
    end

    sql = capture_sql do
      assert_difference -> { Cpk::ChapterDestroyAsync.count }, -2 do
        perform_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
      end
    end

    delete_sqls = sql.select { |sql| sql.start_with?("DELETE") }
    assert_equal 2, delete_sqls.count

    delete_sqls.each do |sql|
      assert_match(/#{Regexp.escape(quote_table_name("cpk_chapters.author_id"))} =/, sql)
    end
  ensure
    Cpk::ChapterDestroyAsync.delete_all
    Cpk::BookDestroyAsync.delete_all
  end

  test "not enqueue the job if transaction is not committed" do
    dl_keyed_has_many = DlKeyedHasMany.new
    parent = DestroyAsyncParent.create!
    parent.dl_keyed_has_many << [dl_keyed_has_many]

    parent.save!
    assert_no_enqueued_jobs do
      DestroyAsyncParent.transaction do
        parent.destroy
        raise ActiveRecord::Rollback
      end
    end
  ensure
    DlKeyedHasMany.delete_all
    DestroyAsyncParent.delete_all
  end

  test "has many ensures function for parent" do
    tag = Tag.create!(name: "Der be treasure")
    tag2 = Tag.create!(name: "Der be rum")
    parent = DestroyAsyncParentSoftDelete.create!
    parent.tags << [tag, tag2]
    parent.save!

    parent.run_callbacks(:destroy)
    parent.run_callbacks(:commit)

    assert_no_difference -> { Tag.count } do
      assert_raises ActiveRecord::DestroyAssociationAsyncError do
        perform_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
      end
    end

    parent.destroy
    assert_difference -> { Tag.count }, -2 do
      perform_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
    end
  ensure
    Tag.delete_all
    DestroyAsyncParentSoftDelete.delete_all
  end

  test "has one ensures function for parent" do
    child = DlKeyedHasOne.create!
    parent = DestroyAsyncParentSoftDelete.create!
    parent.dl_keyed_has_one = child
    parent.save!

    parent.run_callbacks(:destroy)
    parent.run_callbacks(:commit)

    assert_no_difference -> { DlKeyedHasOne.count } do
      assert_raises ActiveRecord::DestroyAssociationAsyncError do
        perform_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
      end
    end

    parent.destroy
    assert_difference -> { DlKeyedHasOne.count }, -1 do
      perform_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
    end
  ensure
    DlKeyedHasOne.delete_all
    DestroyAsyncParentSoftDelete.delete_all
  end

  test "enqueues belongs_to to be deleted with ensuring function" do
    belongs = DlKeyedBelongsToSoftDelete.create!
    parent = DestroyAsyncParentSoftDelete.create!
    belongs.destroy_async_parent_soft_delete = parent
    belongs.save!

    belongs.run_callbacks(:destroy)
    belongs.run_callbacks(:commit)

    assert_raises ActiveRecord::DestroyAssociationAsyncError do
      perform_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
    end

    assert_not parent.reload.deleted?

    belongs.destroy
    perform_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
    assert_predicate parent.reload, :deleted?
  ensure
    DlKeyedBelongsToSoftDelete.delete_all
    DestroyAsyncParentSoftDelete.delete_all
  end

  test "Don't enqueue with no relations" do
    parent = DestroyAsyncParent.create!
    parent.destroy

    assert_no_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
  ensure
    DestroyAsyncParent.delete_all
  end

  test "Rollback prevents jobs from being enqueued" do
    tag = Tag.create!(name: "Der be treasure")
    tag2 = Tag.create!(name: "Der be rum")
    book = BookDestroyAsync.create!
    book.tags << [tag, tag2]
    book.save!
    ActiveRecord::Base.transaction do
      book.destroy
      raise ActiveRecord::Rollback
    end
    assert_no_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
  ensure
    Tag.delete_all
    BookDestroyAsync.delete_all
  end
end
