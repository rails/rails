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

  class ChildCustomDestroyJob < ActiveRecord::DestroyAssociationAsyncJob
    cattr_accessor :call_count, default: 0

    def perform(**options)
      self.class.call_count += 1
      super
    end
  end

  class ParentCustomDestroyJob < ActiveRecord::DestroyAssociationAsyncJob
    cattr_accessor :call_count, default: 0

    def perform(**options)
      self.class.call_count += 1
      super
    end
  end

  class HasOneChildDestroyJob < ActiveRecord::DestroyAssociationAsyncJob
    cattr_accessor :call_count, default: 0

    def perform(**options)
      self.class.call_count += 1
      super
    end
  end

  class HasOneParentDestroyJob < ActiveRecord::DestroyAssociationAsyncJob
    cattr_accessor :call_count, default: 0

    def perform(**options)
      self.class.call_count += 1
      super
    end
  end

  class BelongsToTargetDestroyJob < ActiveRecord::DestroyAssociationAsyncJob
    cattr_accessor :call_count, default: 0

    def perform(**options)
      self.class.call_count += 1
      super
    end
  end

  class BelongsToOwnerDestroyJob < ActiveRecord::DestroyAssociationAsyncJob
    cattr_accessor :call_count, default: 0

    def perform(**options)
      self.class.call_count += 1
      super
    end
  end

  class ThroughTargetDestroyJob < ActiveRecord::DestroyAssociationAsyncJob
    cattr_accessor :call_count, default: 0

    def perform(**options)
      self.class.call_count += 1
      super
    end
  end

  class ThroughSourceDestroyJob < ActiveRecord::DestroyAssociationAsyncJob
    cattr_accessor :call_count, default: 0

    def perform(**options)
      self.class.call_count += 1
      super
    end
  end

  test "uses child model's destroy_association_async_job when available" do
    # Save original jobs
    original_essay_job = EssayDestroyAsync.destroy_association_async_job
    original_book_job = BookDestroyAsync.destroy_association_async_job

    # Reset counters
    ChildCustomDestroyJob.call_count = 0
    ParentCustomDestroyJob.call_count = 0

    # Set custom jobs
    EssayDestroyAsync.destroy_association_async_job = ChildCustomDestroyJob
    BookDestroyAsync.destroy_association_async_job = ParentCustomDestroyJob

    # Create parent with children
    parent = BookDestroyAsync.create!(name: "Parent Book")
    EssayDestroyAsync.create!(name: "Child Essay 1", book_id: parent.id)
    EssayDestroyAsync.create!(name: "Child Essay 2", book_id: parent.id)

    # Destroy parent should use child's job
    assert_enqueued_jobs 1 do
      parent.destroy
    end

    perform_enqueued_jobs

    assert_equal 1, ChildCustomDestroyJob.call_count, "Child's custom job should have been used"
    assert_equal 0, ParentCustomDestroyJob.call_count, "Parent's custom job should not have been used for children"

    # Verify children were destroyed
    assert_equal 0, EssayDestroyAsync.where(book_id: parent.id).count
  ensure
    # Restore original jobs
    EssayDestroyAsync.destroy_association_async_job = original_essay_job
    BookDestroyAsync.destroy_association_async_job = original_book_job
    EssayDestroyAsync.delete_all
    BookDestroyAsync.delete_all
  end

  test "falls back to parent's destroy_association_async_job when child has none" do
    # Save original jobs
    original_essay_job = EssayDestroyAsync.destroy_association_async_job
    original_book_job = BookDestroyAsync.destroy_association_async_job

    # Reset counter
    ParentCustomDestroyJob.call_count = 0

    # Set parent job only (child has none)
    EssayDestroyAsync.destroy_association_async_job = nil
    BookDestroyAsync.destroy_association_async_job = ParentCustomDestroyJob

    # Create parent with children
    parent = BookDestroyAsync.create!(name: "Parent Book")
    EssayDestroyAsync.create!(name: "Child Essay", book_id: parent.id)

    # Destroy parent should fall back to parent's job
    assert_enqueued_jobs 1 do
      parent.destroy
    end

    perform_enqueued_jobs

    assert_equal 1, ParentCustomDestroyJob.call_count, "Parent's custom job should be used as fallback"

    # Verify children were destroyed
    assert_equal 0, EssayDestroyAsync.where(book_id: parent.id).count
  ensure
    # Restore original jobs
    EssayDestroyAsync.destroy_association_async_job = original_essay_job
    BookDestroyAsync.destroy_association_async_job = original_book_job
    EssayDestroyAsync.delete_all
    BookDestroyAsync.delete_all
  end

  test "uses child model's destroy_association_async_job for has_one association" do
    # Save original jobs
    original_content_job = Content.destroy_association_async_job
    original_book_job = BookDestroyAsync.destroy_association_async_job

    # Reset counters
    HasOneChildDestroyJob.call_count = 0
    HasOneParentDestroyJob.call_count = 0

    # Set custom jobs
    Content.destroy_association_async_job = HasOneChildDestroyJob
    BookDestroyAsync.destroy_association_async_job = HasOneParentDestroyJob

    # Create parent with child
    parent = BookDestroyAsync.create!(name: "Test Book")
    Content.create!(book_destroy_async_id: parent.id, title: "Test Content")

    # Destroy parent should use child's job
    assert_enqueued_jobs 1 do
      parent.destroy
    end

    perform_enqueued_jobs

    assert_equal 1, HasOneChildDestroyJob.call_count, "Child's custom job should have been used for has_one"
    assert_equal 0, HasOneParentDestroyJob.call_count, "Parent's custom job should not have been used"

    # Verify child was destroyed
    assert_equal 0, Content.where(book_destroy_async_id: parent.id).count
  ensure
    # Restore original jobs
    Content.destroy_association_async_job = original_content_job
    BookDestroyAsync.destroy_association_async_job = original_book_job
    Content.delete_all
    BookDestroyAsync.delete_all
  end

  test "uses target model's destroy_association_async_job for belongs_to association" do
    # Save original jobs
    original_author_job = Author.destroy_association_async_job
    original_essay_job = EssayDestroyAsync.destroy_association_async_job

    # Reset counters
    BelongsToTargetDestroyJob.call_count = 0
    BelongsToOwnerDestroyJob.call_count = 0

    # Set custom jobs
    Author.destroy_association_async_job = BelongsToTargetDestroyJob
    EssayDestroyAsync.destroy_association_async_job = BelongsToOwnerDestroyJob

    # Create owner with target
    target = Author.create!(name: "Test Author")
    owner = EssayDestroyAsync.create!(name: "Test Essay", writer_id: target.id, writer_type: "Author")

    # Destroy owner should use target's job
    assert_enqueued_jobs 1 do
      owner.destroy
    end

    perform_enqueued_jobs

    assert_equal 1, BelongsToTargetDestroyJob.call_count, "Target's custom job should have been used for belongs_to"
    assert_equal 0, BelongsToOwnerDestroyJob.call_count, "Owner's custom job should not have been used"

    # Verify target was destroyed
    assert_nil Author.find_by(id: target.id)
  ensure
    # Restore original jobs
    Author.destroy_association_async_job = original_author_job
    EssayDestroyAsync.destroy_association_async_job = original_essay_job
    EssayDestroyAsync.delete_all
    Author.delete_all
  end

  test "uses target model's destroy_association_async_job for has_many :through association" do
    # Save original jobs
    original_tag_job = Tag.destroy_association_async_job
    original_book_job = BookDestroyAsync.destroy_association_async_job

    # Reset counters
    ThroughTargetDestroyJob.call_count = 0
    ThroughSourceDestroyJob.call_count = 0

    # Set custom jobs
    Tag.destroy_association_async_job = ThroughTargetDestroyJob
    BookDestroyAsync.destroy_association_async_job = ThroughSourceDestroyJob

    # Create source with targets through join
    source = BookDestroyAsync.create!(name: "Test Book")
    tag1 = Tag.create!(name: "Tag 1")
    tag2 = Tag.create!(name: "Tag 2")
    source.tags << [tag1, tag2]

    # Destroy source should use target's job
    assert_enqueued_jobs 1 do
      source.destroy
    end

    perform_enqueued_jobs

    assert_equal 1, ThroughTargetDestroyJob.call_count,
                 "Target's custom job should have been used for has_many :through"
    assert_equal 0, ThroughSourceDestroyJob.call_count, "Source's custom job should not have been used"

    # Verify targets were destroyed
    assert_equal 0, Tag.where(id: [tag1.id, tag2.id]).count
  ensure
    # Restore original jobs
    Tag.destroy_association_async_job = original_tag_job
    BookDestroyAsync.destroy_association_async_job = original_book_job
    Tag.delete_all
    Tagging.delete_all
    BookDestroyAsync.delete_all
  end
end
