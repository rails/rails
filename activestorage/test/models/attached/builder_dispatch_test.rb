# frozen_string_literal: true

require "test_helper"

class ActiveStorage::Attached::BuilderDispatchTest < ActiveSupport::TestCase
  test "routes active record models to the active record owner builder" do
    builder = ActiveStorage::Attached::Builder.for(User)

    assert_instance_of ActiveStorage::Attached::Builder::ActiveRecordOwner, builder
    assert_equal User, builder.model
  end
end
