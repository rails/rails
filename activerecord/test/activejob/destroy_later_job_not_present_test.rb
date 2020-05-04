# frozen_string_literal: true

require "cases/helper"

class UnusedDestroyLater < ActiveRecord::Base
  self.destroy_association_later_job = nil
  self.destroy_later_job = nil
end

class UnusedBelongsTo < ActiveRecord::Base
  self.destroy_association_later_job = nil
end

class ActiveJobNotPresentTest < ActiveRecord::TestCase
  test "destroy later raises exception when activejob is not present" do
    assert_raises ActiveRecord::ActiveJobRequiredError do
      UnusedDestroyLater.destroy_later after: 10.days
    end
    unused = UnusedDestroyLater.create!
    assert_raises ActiveRecord::ActiveJobRequiredError do
      unused.destroy_later after: 10.days
    end
  end

  test "has_one dependent destroy_later requires activejob" do
    assert_raises ActiveRecord::ActiveJobRequiredError do
      UnusedDestroyLater.has_one :unused_belongs_to, dependent: :destroy_later
    end
  end

  test "has_many dependent destroy_later requires activejob" do
    assert_raises ActiveRecord::ActiveJobRequiredError do
      UnusedDestroyLater.has_many :essay_destroy_laters, dependent: :destroy_later
    end
  end

  test "belong_to dependent destroy_later requires activejob" do
    assert_raises ActiveRecord::ActiveJobRequiredError do
      UnusedBelongsTo.belongs_to :unused_destroy_laters, dependent: :destroy_later
    end
  end
end
