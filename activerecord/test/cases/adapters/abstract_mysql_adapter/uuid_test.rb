# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

if ActiveRecord::Base.connection.supports_uuid?
  module MySQLUUIDHelper
    def connection
      @connection ||= ActiveRecord::Base.lease_connection
    end

    def drop_table(name)
      connection.drop_table name, if_exists: true
    end
  end

  class MySQLUUIDTest < ActiveRecord::AbstractMysqlTestCase
    self.use_transactional_tests = false

    include MySQLUUIDHelper
    include SchemaDumpingHelper

    class UUIDType < ActiveRecord::Base
      self.table_name = "uuid_data_type"
    end

    def setup
      connection.create_table("uuid_data_type", force: true) do |t|
        t.uuid "guid"
      end
    end

    def teardown
      UUIDType.reset_column_information
      connection.drop_table("uuid_data_type")
    end

    def test_uuid_column
      column = UUIDType.columns_hash["guid"]
      assert_equal :uuid, column.type
      assert_equal "uuid", column.sql_type
    end

    def test_treat_blank_uuid_as_nil
      UUIDType.create!(guid: "")
      assert_nil UUIDType.last.guid
    end

    def test_treat_invalid_uuid_as_nil
      uuid = UUIDType.create!(guid: "foobar")
      assert_nil uuid.guid
    end

    def test_invalid_uuid_dont_modify_before_type_cast
      uuid = UUIDType.new(guid: "foobar")
      assert_equal "foobar", uuid.guid_before_type_cast
    end

    def test_invalid_uuid_dont_match_to_nil
      UUIDType.create!
      assert_empty UUIDType.where(guid: "")
      assert_empty UUIDType.where(guid: "foobar")
    end

    def test_uuid_change_case_does_not_mark_dirty
      model = UUIDType.create!(guid: "abcd-0123-4567-89ef-dead-beef-0101-1010")
      model.guid = model.guid.swapcase
      assert_not_predicate model, :changed?
    end

    class DuckUUID
      def initialize(uuid)
        @uuid = uuid
      end

      def to_s
        @uuid
      end
    end

    def test_acceptable_uuid_regex
      # Valid uuids
      ["f8aa-ed66-1a1b-11ec-ab4e-f859-713e-4be4",
        "F8AA-ED66-1A1B-11EC-AB4E-F859-713E-4BE4",
        "f8aaed661a1b11ecab4ef859713e4be4",
        "f8aaed66-1a1b-11ec-ab4e-f859-713e-4be4",
        "f8aaed66-1-a---1b-11ec-ab4e-f859-713e-4be4",
        "f8aa-ed66-1a1b-11ec-ab4e-f859-713e-4be4",
        "F8AA-ED66-1A1B-11EC-AB4E-F859-713E-4BE4",
       DuckUUID.new("f8aa-ed66-1a1b-11ec-ab4e-f859-713e-4be4"),
      ].each do |valid_uuid|
        uuid = UUIDType.new guid: valid_uuid
        assert_instance_of String, uuid.guid
      end

      # Invalid uuids
      [["F8AA-ED66-1A1B-11EC-AB4E-F859-713E-4BE4"],
       Hash.new,
       0,
       0.0,
       true,
       "{f8aa-ed66-1a1b-11ec-ab4e-f859-713e-4be4}",
       "f8aa-ed66-1a1b-11ec-ab4e-f859-713e-4be",
       "f8aa-ed66-1a1b-11ec-ab4e-f859-713e-4be4-"].each do |invalid_uuid|
        uuid = UUIDType.new guid: invalid_uuid
        assert_nil uuid.guid
      end
    end

    def test_uuid_formats
      ["A0EEBC99-9C0B-4EF8-BB6D-6BB9BD380A11",
       "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11",
       "a0eebc999c0b4ef8bb6d6bb9bd380a11",
       "a0ee-bc99-9c0b-4ef8-bb6d-6bb9-bd38-0a11"].each do |valid_uuid|
        UUIDType.create(guid: valid_uuid)
        uuid = UUIDType.last
        assert_equal "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11", uuid.guid
      end
    end

    def test_schema_dump_with_shorthand
      output = dump_table_schema("uuid_data_type")
      assert_match %r{t\.uuid "guid"}, output
    end

    def test_uniqueness_validation_ignores_uuid
      klass = Class.new(ActiveRecord::Base) do
        self.table_name = "uuid_data_type"
        validates :guid, uniqueness: { case_sensitive: false }

        def self.name
          "UUIDType"
        end
      end

      record = klass.create!(guid: "a0ee-bc99-9c0b-4ef8-bb6d-6bb9-bd38-0a11")
      duplicate = klass.new(guid: record.guid)

      assert_predicate record.guid, :present? # Ensure we actually are testing a UUID
      assert_not_predicate duplicate, :valid?
    end
  end

  class MySQLUUIDGenerationTest < ActiveRecord::AbstractMysqlTestCase
    self.use_transactional_tests = false

    include MySQLUUIDHelper
    include SchemaDumpingHelper

    class UUID < ActiveRecord::Base
      self.table_name = "mysql_uuids"
    end

    def setup
      connection.create_table("mysql_uuids", id: :uuid, force: true) do |t|
        t.uuid "other_uuid", default: "uuid()"
      end

      # Create such a table with other system function as default value generator
      connection.create_table("mysql_uuids_2", id: :uuid, default: "sys_guid()", force: true) do |t|
        t.uuid "other_uuid_2", default: "sys_guid()"
      end
    end

    def teardown
      connection.drop_table("mysql_uuids")
      connection.drop_table("mysql_uuids_2")
    end

    def test_id_is_uuid
      column = UUID.columns_hash["id"]

      assert_equal :uuid, column.type
      assert_equal "uuid", column.sql_type
      assert_equal "uuid()", column.default_function
      assert UUID.primary_key
    end

    def test_defaults_are_populated
      u = UUID.create!
      assert_not_nil u.id
      assert_not_nil u.other_uuid
    end

    def test_schema_dumper_for_uuid_primary_key
      schema = dump_table_schema("mysql_uuids")
      assert_match(/\bcreate_table "mysql_uuids", id: :uuid, default: -> { "uuid\(\)" }/, schema)
      assert_match(/t\.uuid "other_uuid", default: -> { "uuid\(\)" }/, schema)
    end

    def test_schema_dumper_for_uuid_primary_key_with_custom_default
      schema = dump_table_schema("mysql_uuids_2")
      assert_match(/\bcreate_table "mysql_uuids_2", id: :uuid, default: -> { "sys_guid\(\)" }/, schema)
      assert_match(/t\.uuid "other_uuid_2", default: -> { "sys_guid\(\)" }/, schema)
    end
  end

  class MySQLUUIDTestInverseOf < ActiveRecord::AbstractMysqlTestCase
    self.use_transactional_tests = false

    include MySQLUUIDHelper

    class UuidPost < ActiveRecord::Base
      self.table_name = "uuid_posts"
      has_many :uuid_comments, inverse_of: :uuid_post
    end

    class UuidComment < ActiveRecord::Base
      self.table_name = "uuid_comments"
      belongs_to :uuid_post
    end

    def setup
      connection.create_table("uuid_posts", id: :uuid, force: true) do |t|
        t.string "title"
      end
      connection.create_table("uuid_comments", id: :uuid, force: true) do |t|
        t.references "uuid_post", type: :uuid
        t.string "content"
      end
    end

    def teardown
      connection.drop_table("uuid_comments")
      connection.drop_table("uuid_posts")
    end

    def test_collection_association_with_uuid
      post = UuidPost.create!
      comment = post.uuid_comments.create!
      assert_equal comment, post.uuid_comments.find(comment.id)
    end

    def test_find_with_uuid
      UuidPost.create!
      assert_raise(ActiveRecord::RecordNotFound) do
        UuidPost.find(123456)
      end
    end

    def test_find_by_with_uuid
      UuidPost.create!
      assert_nil UuidPost.find_by(id: 789)
    end
  end
end
