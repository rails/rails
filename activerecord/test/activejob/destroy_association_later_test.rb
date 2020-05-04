# frozen_string_literal: true

require "activejob/helper"

require "models/book_destroy_later"
require "models/essay_destroy_later"
require "models/tag"
require "models/tagging"
require "models/essay"
require "models/category"
require "models/post"
require "models/content"
require "models/destroy_later_parent"
require "models/destroy_later_parent_soft_delete"
require "models/dl_keyed_belongs_to"
require "models/dl_keyed_belongs_to_soft_delete"
require "models/dl_keyed_has_one"
require "models/dl_keyed_join"
require "models/dl_keyed_has_many"
require "models/dl_keyed_has_many_through"

class DestroyAssociationLaterTest < ActiveRecord::TestCase
  include ActiveJob::TestHelper

  test "destroying a record destroys the has_many :through records using a job" do
    tag = Tag.create!(name: "Der be treasure")
    tag2 = Tag.create!(name: "Der be rum")
    book = BookDestroyLater.create!
    book.tags << [tag, tag2]
    book.save!

    book.destroy

    assert_difference -> { Tag.count }, -2 do
      perform_enqueued_jobs only: ActiveRecord::DestroyAssociationLaterJob
    end
  end

  test "destroying a scoped has_many through only deletes within the scope deleted" do
    tag = Tag.create!(name: "Der be treasure")
    tag2 = Tag.create!(name: "Der be rum")
    parent = BookDestroyLaterWithScopedTags.create!
    parent.tags << [tag, tag2]
    parent.save!

    parent.reload # force the association to be reloaded

    parent.destroy

    assert_difference -> { Tag.count }, -1 do
      perform_enqueued_jobs only: ActiveRecord::DestroyAssociationLaterJob
    end
    assert_raises ActiveRecord::RecordNotFound do
      tag2.reload
    end
    assert tag.reload
  end

  test "enqueues the has_many through to be deleted with custom primary key" do
    dl_keyed_has_many = DlKeyedHasManyThrough.create!
    dl_keyed_has_many2 = DlKeyedHasManyThrough.create!
    parent = DestroyLaterParent.create!
    parent.dl_keyed_has_many_through << [dl_keyed_has_many2, dl_keyed_has_many]
    parent.save!
    parent.destroy

    assert_difference -> { DlKeyedJoin.count }, -2 do
     assert_difference -> { DlKeyedHasManyThrough.count }, -2 do
      perform_enqueued_jobs only: ActiveRecord::DestroyAssociationLaterJob
    end
   end
  end

  test "belongs to" do
    essay = EssayDestroyLater.create!(name: "Der be treasure")
    book = BookDestroyLater.create!(name: "Arr, matey!")
    essay.book = book
    essay.save!
    essay.destroy

    assert_difference -> { BookDestroyLater.count }, -1 do
      perform_enqueued_jobs only: ActiveRecord::DestroyAssociationLaterJob
    end
  end

  test "enqueues belongs_to to be deleted with custom primary key" do
    belongs = DlKeyedBelongsTo.create!
    parent = DestroyLaterParent.create!
    belongs.destroy_later_parent = parent
    belongs.save!
    belongs.destroy

    assert_difference -> { DestroyLaterParent.count }, -1 do
      perform_enqueued_jobs only: ActiveRecord::DestroyAssociationLaterJob
    end
  end

  test "has_one" do
    content = Content.create(title: "hello")
    book = BookDestroyLater.create!(name: "Arr, matey!")
    book.content = content
    book.save!
    book.destroy

    assert_difference -> { Content.count }, -1 do
      perform_enqueued_jobs only: ActiveRecord::DestroyAssociationLaterJob
    end
  end


  test "enqueues has_one to be deleted with custom primary key" do
    child = DlKeyedHasOne.create!
    parent = DestroyLaterParent.create!
    parent.dl_keyed_has_one = child
    parent.save!
    parent.destroy

    assert_difference -> { DlKeyedHasOne.count }, -1 do
      perform_enqueued_jobs only: ActiveRecord::DestroyAssociationLaterJob
    end
  end


  test "has_many" do
    essay = EssayDestroyLater.create!(name: "Der be treasure")
    essay2 = EssayDestroyLater.create!(name: "Der be rum")
    book = BookDestroyLater.create!(name: "Arr, matey!")
    book.essays << [essay, essay2]
    book.save!
    book.destroy

    assert_difference -> { EssayDestroyLater.count }, -2 do
      perform_enqueued_jobs only: ActiveRecord::DestroyAssociationLaterJob
    end
  end


  test "enqueues the has_many to be deleted with custom primary key" do
    dl_keyed_has_many = DlKeyedHasMany.new
    parent = DestroyLaterParent.create!
    parent.dl_keyed_has_many << [dl_keyed_has_many]

    parent.save!
    parent.destroy

    assert_difference -> { DlKeyedHasMany.count }, -1 do
      perform_enqueued_jobs only: ActiveRecord::DestroyAssociationLaterJob
    end
  end

  test "throw an error if the record is not actually deleted" do
    dl_keyed_has_many = DlKeyedHasMany.new
    parent = DestroyLaterParent.create!
    parent.dl_keyed_has_many << [dl_keyed_has_many]

    parent.save!
    DestroyLaterParent.transaction do
      parent.destroy
      raise ActiveRecord::Rollback
    end

    assert_difference -> { DlKeyedHasMany.count }, 0 do
      assert_raises ActiveRecord::DestroyAssociationLaterError do
        perform_enqueued_jobs only: ActiveRecord::DestroyAssociationLaterJob
      end
    end
  end

  test "has many ensures function for parent" do
    tag = Tag.create!(name: "Der be treasure")
    tag2 = Tag.create!(name: "Der be rum")
    parent = DestroyLaterParentSoftDelete.create!
    parent.tags << [tag, tag2]
    parent.save!

    parent.run_callbacks(:destroy)

    assert_difference -> { Tag.count }, -0 do
      assert_raises ActiveRecord::DestroyAssociationLaterError do
        perform_enqueued_jobs only: ActiveRecord::DestroyAssociationLaterJob
      end
    end

    parent.destroy
    assert_difference -> { Tag.count }, -2 do
      perform_enqueued_jobs only: ActiveRecord::DestroyAssociationLaterJob
    end
  end

  test "has one ensures function for parent" do
    child = DlKeyedHasOne.create!
    parent = DestroyLaterParentSoftDelete.create!
    parent.dl_keyed_has_one = child
    parent.save!

    parent.run_callbacks(:destroy)

    assert_difference -> { DlKeyedHasOne.count }, -0 do
      assert_raises ActiveRecord::DestroyAssociationLaterError do
        perform_enqueued_jobs only: ActiveRecord::DestroyAssociationLaterJob
      end
    end

    parent.destroy
    assert_difference -> { DlKeyedHasOne.count }, -1 do
      perform_enqueued_jobs only: ActiveRecord::DestroyAssociationLaterJob
    end
  end

  test "enqueues belongs_to to be deleted with ensuring function" do
    belongs = DlKeyedBelongsToSoftDelete.create!
    parent = DestroyLaterParentSoftDelete.create!
    belongs.destory_later_parent_soft_delete = parent
    belongs.save!
    belongs.run_callbacks(:destroy)

    assert_raises ActiveRecord::DestroyAssociationLaterError do
      perform_enqueued_jobs only: ActiveRecord::DestroyAssociationLaterJob
    end

    assert_not parent.reload.deleted?

    belongs.destroy
    perform_enqueued_jobs only: ActiveRecord::DestroyAssociationLaterJob
    assert parent.reload.deleted?
  end

  test "Don't enqueue with no relations" do
    parent = DestroyLaterParent.create!
    parent.destroy

    assert_no_enqueued_jobs only: ActiveRecord::DestroyAssociationLaterJob
  end
end
