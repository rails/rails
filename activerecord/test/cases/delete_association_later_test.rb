# frozen_string_literal: true

require "cases/helper"

require "models/delete_association_parent"
require "models/da_belongs_to"
require "models/da_has_one"
require "models/da_join"
require "models/da_has_many"
require "models/da_has_many_through"

class DeleteAssociationLaterTest < ActiveRecord::TestCase
  include ActiveJob::TestHelper

  test "enqueues the has_many through to be deleted" do
   da_has_many = DaHasManyThrough.create!
   da_has_many2 = DaHasManyThrough.create!
   parent = DeleteAssociationParent.create!
   parent.da_has_many_through << [da_has_many2, da_has_many]
   parent.save!
   parent.destroy
   assert_enqueued_with job: ActiveRecord::DeleteAssociationLaterJob

   assert_difference -> { DaJoin.count }, -2 do
    assert_difference -> { DaHasManyThrough.count }, -2 do
      perform_enqueued_jobs only: ActiveRecord::DeleteAssociationLaterJob
    end
  end
 end

  test "belongs to" do
    parent = DeleteAssociationParent.create!
    da_belongs_to = DaBelongsTo.create!
    da_belongs_to.delete_association_parent = parent
    da_belongs_to.save!
    da_belongs_to.destroy

    assert_enqueued_with job: ActiveRecord::DeleteAssociationLaterJob

    assert_difference -> { DeleteAssociationParent.count }, -1 do
     perform_enqueued_jobs only: ActiveRecord::DeleteAssociationLaterJob
   end
  end

  test "has_one" do
    parent = DeleteAssociationParent.create!
    da_has_one = DaHasOne.create!
    parent.da_has_one = da_has_one
    parent.save!
    parent.destroy
    assert_enqueued_with job: ActiveRecord::DeleteAssociationLaterJob

    assert_difference -> { DaHasOne.count }, -1 do
     perform_enqueued_jobs only: ActiveRecord::DeleteAssociationLaterJob
   end
  end

  test "has_many" do
    da_has_many = DaHasMany.create!
    da_has_many2 = DaHasMany.create!
    parent = DeleteAssociationParent.create!
    parent.da_has_many << [da_has_many2, da_has_many]
    parent.save!
    parent.destroy
    assert_enqueued_with job: ActiveRecord::DeleteAssociationLaterJob

    assert_difference -> { DaHasMany.count }, -2 do
     perform_enqueued_jobs only: ActiveRecord::DeleteAssociationLaterJob
   end
  end
end
