# frozen_string_literal: true

require "cases/helper"

class IdMappedReferenceTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  class Profile < ActiveRecord::Base
    self.table_name = "id_mapped_profiles"
    self.primary_key = :uuid

    belongs_to :user, class_name: "IdMappedReferenceTest::User", foreign_key: :id, inverse_of: false, optional: true
  end

  class User < ActiveRecord::Base
    self.table_name = "id_mapped_users"

    has_one :profile, class_name: "IdMappedReferenceTest::Profile", foreign_key: :id, inverse_of: false
  end

  setup do
    @connection = main_ractor_connection(ActiveRecord::Base.lease_connection)
    @connection.create_table(:id_mapped_users, force: true)
    @connection.create_table(:id_mapped_profiles, id: false, force: true) do |t|
      t.string :uuid, primary_key: true
      t.integer :id
    end
  end

  teardown do
    @connection&.drop_table(:id_mapped_profiles, if_exists: true)
    @connection&.drop_table(:id_mapped_users, if_exists: true)
  end

  def test_has_one_assignment_writes_the_primary_key
    user = User.create!
    profile = Profile.new(uuid: "initial")

    assert_deprecated(ActiveRecord.deprecator) do
      user.profile = profile
    end

    assert_equal user.id.to_s, profile.uuid
    assert_nil profile._read_attribute("id")
  end

  # Through the public API, a nullified profile is then saved without its
  # primary key, so this exercises the nullification on its own.
  def test_has_one_nullify_writes_the_primary_key
    user = User.create!
    profile = Profile.new(uuid: "initial")
    profile._write_attribute("id", user.id)

    assert_deprecated(ActiveRecord.deprecator) do
      user.association(:profile).send(:nullify_owner_attributes, profile)
    end

    assert_nil profile.uuid
    assert_equal user.id, profile._read_attribute("id")
  end

  def test_belongs_to_assignment_writes_the_primary_key
    user = User.create!
    profile = Profile.new(uuid: "initial")

    assert_deprecated(ActiveRecord.deprecator) do
      profile.user = user
    end

    assert_equal user.id.to_s, profile.uuid
    assert_nil profile._read_attribute("id")
  end
end
