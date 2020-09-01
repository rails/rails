# frozen_string_literal: true

require "cases/helper"

class UnusedDestroyLater < ActiveRecord::Base
  self.destroy_later_job = nil
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
end
