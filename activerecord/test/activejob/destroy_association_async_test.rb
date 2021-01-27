# frozen_string_literal: true

require "activejob/helper"

require "models/book_destroy_async"
require "models/essay_destroy_async"
require "models/tag"
require "models/tagging"
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

class DestroyAssociationAsyncTest < ActiveRecord::TestCase
  include ActiveJob::TestHelper

  test "destroying a record destroys the has_many :through records using a job" do
    tag = Tag.create!(name: "Der be treasure")
    tag2 = Tag.create!(name: "Der be rum")
    book = BookDestroyAsync.create!
    book.tags << [tag, tag2]
    book.save!

    book.destroy

    assert_difference -> { Tag.count }, -2 do
      perform_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
    end
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
  end

  test "throw an error if the record is not actually deleted" do
    dl_keyed_has_many = DlKeyedHasMany.new
    parent = DestroyAsyncParent.create!
    parent.dl_keyed_has_many << [dl_keyed_has_many]

    parent.save!
    parent.run_callbacks(:destroy)
    parent.send(:enqueue_waiting_jobs)

    assert_difference -> { DlKeyedHasMany.count }, 0 do
      assert_raises ActiveRecord::DestroyAssociationAsyncError do
        perform_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
      end
    end
  end

  test "has many ensures function for parent" do
    tag = Tag.create!(name: "Der be treasure")
    tag2 = Tag.create!(name: "Der be rum")
    parent = DestroyAsyncParentSoftDelete.create!
    parent.tags << [tag, tag2]
    parent.save!

    parent.run_callbacks(:destroy)
    parent.send(:enqueue_waiting_jobs)

    assert_difference -> { Tag.count }, -0 do
      assert_raises ActiveRecord::DestroyAssociationAsyncError do
        perform_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
      end
    end

    parent.destroy
    assert_difference -> { Tag.count }, -2 do
      perform_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
    end
  end

  test "has one ensures function for parent" do
    child = DlKeyedHasOne.create!
    parent = DestroyAsyncParentSoftDelete.create!
    parent.dl_keyed_has_one = child
    parent.save!

    parent.run_callbacks(:destroy)
    parent.send(:enqueue_waiting_jobs)

    assert_difference -> { DlKeyedHasOne.count }, -0 do
      assert_raises ActiveRecord::DestroyAssociationAsyncError do
        perform_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
      end
    end

    parent.destroy
    assert_difference -> { DlKeyedHasOne.count }, -1 do
      perform_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
    end
  end

  test "enqueues belongs_to to be deleted with ensuring function" do
    belongs = DlKeyedBelongsToSoftDelete.create!
    parent = DestroyAsyncParentSoftDelete.create!
    belongs.destroy_async_parent_soft_delete = parent
    belongs.save!
    belongs.run_callbacks(:destroy)
    belongs.send(:enqueue_waiting_jobs)


    assert_raises ActiveRecord::DestroyAssociationAsyncError do
      perform_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
    end

    assert_not parent.reload.deleted?

    belongs.destroy
    perform_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
    assert parent.reload.deleted?
  end

  test "Don't enqueue with no relations" do
    parent = DestroyAsyncParent.create!
    parent.destroy

    assert_no_enqueued_jobs only: ActiveRecord::DestroyAssociationAsyncJob
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
  end
end
