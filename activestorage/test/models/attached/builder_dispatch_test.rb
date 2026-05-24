# frozen_string_literal: true

require "test_helper"

class ActiveStorage::Attached::BuilderDispatchTest < ActiveSupport::TestCase
  test "routes active record models to the active record owner builder" do
    builder = ActiveStorage::Attached::Builder.for(User)

    assert_instance_of ActiveStorage::Attached::Builder::ActiveRecordOwner, builder
    assert_equal User, builder.model
  end

  test "routes non active record models to the generic builder" do
    model = Class.new
    builder = ActiveStorage::Attached::Builder.for(model)

    assert_instance_of ActiveStorage::Attached::Builder::Generic, builder
    assert_equal model, builder.model
  end

  test "routes active model owners to the generic builder" do
    model = Class.new do
      include ActiveModel::Model
      include ActiveStorage::Attached::Model
      extend ActiveModel::Callbacks

      define_model_callbacks :save, :destroy

      def self.find(id)
      end
    end

    builder = ActiveStorage::Attached::Builder.for(model)

    assert_instance_of ActiveStorage::Attached::Builder::Generic, builder
    assert_equal model, builder.model
  end
end
