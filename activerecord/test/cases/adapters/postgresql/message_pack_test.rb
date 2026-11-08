# frozen_string_literal: true

require "cases/helper"
require "active_support/message_pack"
require "active_record/message_pack"

class PostgresqlMessagePackTest < ActiveRecord::PostgreSQLTestCase
  class PostgresqlMessagePackRecord < ActiveRecord::Base
    self.table_name = "postgresql_message_pack_records"
  end

  def setup
    @connection = ActiveRecord::Base.lease_connection
    @connection.create_table("postgresql_message_pack_records", force: true) do |t|
      t.string :tags, array: true
      t.integer :ratings, array: true
      t.string :matrix, array: true
      t.timestamp :timestamps, array: true, precision: 6
      t.bit :a_bit, limit: 8
      t.bit :bits, limit: 8, array: true
      t.xml :payload
    end
    PostgresqlMessagePackRecord.reset_column_information
  end

  def teardown
    @connection.drop_table "postgresql_message_pack_records", if_exists: true
  end

  def test_roundtrips_array_bit_and_xml_attributes
    record = PostgresqlMessagePackRecord.find(PostgresqlMessagePackRecord.create!(
      tags: ["ruby", "rails", "", nil],
      ratings: [1, nil, 3],
      matrix: [["a", "b"], ["c", "d"]],
      timestamps: [Time.utc(2026, 11, 6, 1, 2, 3, 456789)],
      a_bit: "00000011",
      bits: ["00000001", "00000010"],
      payload: "<foo>bar</foo>"
    ).id)

    roundtripped = roundtrip(record)

    assert_equal record.attributes, roundtripped.attributes
    assert_not_predicate roundtripped, :changed?
  end

  def test_roundtripped_record_tracks_changes_and_saves
    record = PostgresqlMessagePackRecord.find(PostgresqlMessagePackRecord.create!(tags: ["ruby"], a_bit: "00000011", payload: "<foo/>").id)

    roundtripped = roundtrip(record)
    roundtripped.tags << "rails"
    roundtripped.a_bit = "00000100"
    roundtripped.payload = "<bar/>"

    assert_equal ["tags", "a_bit", "payload"], roundtripped.changed
    roundtripped.save!
    assert_equal({ "tags" => ["ruby", "rails"], "a_bit" => "00000100", "payload" => "<bar/>" },
      record.reload.attributes.slice("tags", "a_bit", "payload"))
  end

  def test_roundtrips_new_record_with_array_bit_and_xml_attributes
    record = PostgresqlMessagePackRecord.new(tags: ["ruby"], a_bit: "00000011", payload: "<foo/>")

    roundtripped = roundtrip(record)

    assert_equal record.attributes, roundtripped.attributes
    assert_predicate roundtripped, :new_record?
  end

  private
    # Installs the same extensions as ActiveSupport::MessagePack::CacheSerializer
    # once the Active Record railtie has added its own.
    def serializer
      @serializer ||= ::MessagePack::Factory.new.tap do |factory|
        ActiveRecord::MessagePack::Extensions.install(factory)
        ActiveSupport::MessagePack::Extensions.install(factory)
        ActiveSupport::MessagePack::Extensions.install_unregistered_type_fallback(factory)
      end
    end

    def roundtrip(input)
      serializer.load(serializer.dump(input))
    end
end
