# frozen_string_literal: true

require "cases/helper"

class ColumnLimitValidationTest < ActiveRecord::TestCase
  # The validation only fires for columns whose adapter reports a limit, so the
  # suite is scoped to the adapters that report one for the columns it builds.
  if current_adapter?(:PostgreSQLAdapter, :Mysql2Adapter, :TrilogyAdapter, :SQLite3Adapter)
    self.use_transactional_tests = false

    class Ledger < ActiveRecord::Base
      alias_attribute :reference, :code
    end

    setup do
      @connection = ActiveRecord::Base.lease_connection
      @connection.create_table(:ledgers, force: true) do |t|
        t.integer :account_id, limit: 2
        t.string  :code, limit: 5
        t.text    :notes
        t.decimal :amount, precision: 5, scale: 2
        t.binary  :payload, limit: 10
      end
      Ledger.reset_column_information
    end

    teardown do
      @connection.drop_table :ledgers, if_exists: true
      Ledger.clear_validators!
    end

    MAX_TWO_BYTE_SIGNED = 2**15 - 1
    private_constant :MAX_TWO_BYTE_SIGNED

    def test_integer_within_the_column_limit_is_valid
      assert_equal 2, Ledger.columns_hash["account_id"].limit
      Ledger.validates_column_limit_of :account_id

      assert_predicate Ledger.new(account_id: MAX_TWO_BYTE_SIGNED), :valid?
      assert_predicate Ledger.new(account_id: -MAX_TWO_BYTE_SIGNED - 1), :valid?
    end

    def test_integer_above_the_column_limit_is_invalid
      Ledger.validates_column_limit_of :account_id

      subject = Ledger.new(account_id: MAX_TWO_BYTE_SIGNED + 1)

      assert_not_predicate subject, :valid?
      assert_equal ["is too large (maximum is #{MAX_TWO_BYTE_SIGNED})"], subject.errors[:account_id]
    end

    def test_integer_below_the_column_limit_is_invalid
      Ledger.validates_column_limit_of :account_id

      subject = Ledger.new(account_id: -MAX_TWO_BYTE_SIGNED - 2)

      assert_not_predicate subject, :valid?
      assert_equal ["is too small (minimum is #{-MAX_TWO_BYTE_SIGNED - 1})"], subject.errors[:account_id]
    end

    def test_integer_wider_attribute_type_is_still_bound_to_the_column
      model = Class.new(Ledger) do
        def self.name; "Ledger"; end
        attribute :account_id, :integer, limit: 4
        validates_column_limit_of :account_id
      end

      # 32768 fits the 4-byte attribute type; the 2-byte column cannot hold it.
      subject = model.new(account_id: MAX_TWO_BYTE_SIGNED + 1)
      assert_not_predicate subject, :valid?
      assert_equal ["is too large (maximum is #{MAX_TWO_BYTE_SIGNED})"], subject.errors[:account_id]
    end

    def test_below_range_enum_reports_the_lower_bound
      @connection.create_table(:enum_ints, force: true) { |t| t.integer :status, limit: 2 }
      klass = Class.new(ActiveRecord::Base) do
        def self.name; "Reading"; end
        self.table_name = "enum_ints"
        enum :status, { under: -MAX_TWO_BYTE_SIGNED - 2, ok: 1 }
        validates_column_limit_of :status
      end

      subject = klass.new(status: :under)
      assert_not_predicate subject, :valid?
      assert_equal ["is too small (minimum is #{-MAX_TWO_BYTE_SIGNED - 1})"], subject.errors[:status]
    ensure
      @connection.drop_table :enum_ints, if_exists: true
    end

    def test_string_within_the_column_limit_is_valid
      assert_equal 5, Ledger.columns_hash["code"].limit
      Ledger.validates_column_limit_of :code

      assert_predicate Ledger.new(code: "abcde"), :valid?
    end

    def test_string_above_the_column_limit_is_invalid
      Ledger.validates_column_limit_of :code

      subject = Ledger.new(code: "abcdef")

      assert_not_predicate subject, :valid?
      assert_equal ["is too long (maximum is 5 characters)"], subject.errors[:code]
    end

    def test_string_limit_counts_characters_not_bytes
      Ledger.validates_column_limit_of :code

      # Five two-byte characters are five characters but ten bytes; the limit is 5.
      assert_predicate Ledger.new(code: "é" * 5), :valid?
    end

    def test_message_option_overrides_the_default
      Ledger.validates_column_limit_of :code, message: "is too big"

      subject = Ledger.new(code: "abcdef")

      assert_not_predicate subject, :valid?
      assert_equal ["is too big"], subject.errors[:code]
    end

    def test_aliased_attribute_resolves_to_the_backing_column
      Ledger.validates_column_limit_of :reference

      assert_predicate Ledger.new(reference: "abcde"), :valid?

      subject = Ledger.new(reference: "abcdef")
      assert_not_predicate subject, :valid?
      assert_equal ["is too long (maximum is 5 characters)"], subject.errors[:reference]
    end

    def test_integer_enum_validates_the_stored_value
      @connection.create_table(:enum_ints, force: true) { |t| t.integer :status, limit: 2 }
      klass = Class.new(ActiveRecord::Base) do
        self.table_name = "enum_ints"
        enum :status, { pending: 0, active: 1 }
        validates_column_limit_of :status
      end

      # The public value is "pending"; the column stores 0.
      assert_predicate klass.new(status: :pending), :valid?
    ensure
      @connection.drop_table :enum_ints, if_exists: true
    end

    def test_string_enum_validates_the_stored_value
      @connection.create_table(:enum_strings, force: true) { |t| t.string :flag, limit: 1 }
      klass = Class.new(ActiveRecord::Base) do
        self.table_name = "enum_strings"
        enum :flag, { small: "s", big: "b" }
        validates_column_limit_of :flag
      end

      # The label "small" is five characters, but the stored "s" fits varchar(1).
      assert_predicate klass.new(flag: :small), :valid?
    ensure
      @connection.drop_table :enum_strings, if_exists: true
    end

    def test_serialized_attribute_measures_the_stored_string
      @connection.create_table(:serialized_things, force: true) { |t| t.string :prefs, limit: 20 }
      klass = Class.new(ActiveRecord::Base) do
        self.table_name = "serialized_things"
        serialize :prefs, coder: JSON
        validates_column_limit_of :prefs
      end

      subject = klass.new(prefs: { "note" => "x" * 30 })
      assert_not_predicate subject, :valid?
    ensure
      @connection.drop_table :serialized_things, if_exists: true
    end

    def test_decimal_within_the_column_limit_is_valid
      assert_equal 5, Ledger.columns_hash["amount"].precision
      assert_equal 2, Ledger.columns_hash["amount"].scale
      Ledger.validates_column_limit_of :amount

      assert_predicate Ledger.new(amount: "999.99"), :valid?
      assert_predicate Ledger.new(amount: "-999.99"), :valid?
      # Rounds to scale before validating, so this fits as 999.99.
      assert_predicate Ledger.new(amount: "999.994"), :valid?
    end

    def test_decimal_above_the_column_limit_is_invalid
      Ledger.validates_column_limit_of :amount

      subject = Ledger.new(amount: "1000")

      assert_not_predicate subject, :valid?
      assert_equal ["is too large (maximum is 999.99)"], subject.errors[:amount]
    end

    def test_decimal_below_the_column_limit_is_invalid
      Ledger.validates_column_limit_of :amount

      subject = Ledger.new(amount: "-1000")

      assert_not_predicate subject, :valid?
      assert_equal ["is too small (minimum is -999.99)"], subject.errors[:amount]
    end

    def test_non_finite_decimal_is_rejected
      Ledger.validates_column_limit_of :amount

      [BigDecimal("NaN"), BigDecimal("Infinity")].each do |value|
        subject = Ledger.new(amount: value)
        assert_not_predicate subject, :valid?
        assert_equal ["is not a number"], subject.errors[:amount]
      end
    end

    def test_integer_type_that_serializes_to_a_string_is_measured
      string_integer = Class.new(ActiveModel::Type::Integer) do
        def serialize(value); super.to_s; end
      end
      model = Class.new(Ledger) do
        def self.name; "Ledger"; end
        attribute :account_id, string_integer.new(limit: 2)
        validates_column_limit_of :account_id
      end

      assert_predicate model.new(account_id: 1), :valid?
      assert_not_predicate model.new(account_id: MAX_TWO_BYTE_SIGNED + 1), :valid?
    end

    def test_decimal_type_that_serializes_to_a_string_is_measured
      string_decimal = Class.new(ActiveModel::Type::Decimal) do
        def serialize(value); super.to_s("F"); end
      end
      model = Class.new(Ledger) do
        def self.name; "Ledger"; end
        attribute :amount, string_decimal.new(precision: 5, scale: 2)
        validates_column_limit_of :amount
      end

      assert_predicate model.new(amount: "1.23"), :valid?
      assert_not_predicate model.new(amount: "1000"), :valid?
    end

    def test_nil_is_skipped
      Ledger.validates_column_limit_of :account_id

      assert_predicate Ledger.new(account_id: nil), :valid?
    end

    def test_virtual_attribute_raises_even_when_nil
      model_class = Class.new(ActiveRecord::Base) do
        self.table_name = "ledgers"
        attribute :virtual_amount, :integer
        validates_column_limit_of :virtual_amount
      end

      [1, nil].each do |value|
        error = assert_raises(ArgumentError) { model_class.new(virtual_amount: value).valid? }
        assert_equal "cannot validate the column limit of :virtual_amount, which is not backed by a column", error.message
      end
    end

    if current_adapter?(:SQLite3Adapter, :Mysql2Adapter, :TrilogyAdapter)
      def test_binary_within_the_column_limit_is_valid
        assert_equal 10, Ledger.columns_hash["payload"].limit
        Ledger.validates_column_limit_of :payload

        assert_predicate Ledger.new(payload: "0123456789"), :valid?
      end

      def test_binary_above_the_column_limit_is_invalid
        Ledger.validates_column_limit_of :payload

        subject = Ledger.new(payload: "0123456789A")

        assert_not_predicate subject, :valid?
        assert_equal ["is too large (maximum is 10 bytes)"], subject.errors[:payload]
      end

      def test_binary_limit_counts_bytes_not_characters
        Ledger.validates_column_limit_of :payload

        # Six two-byte characters are twelve bytes over the ten-byte column, though
        # only six characters long.
        subject = Ledger.new(payload: "é" * 6)

        assert_not_predicate subject, :valid?
      end
    end

    if current_adapter?(:PostgreSQLAdapter)
      def test_array_column_is_skipped
        @connection.create_table(:baskets, force: true) { |t| t.integer :sizes, limit: 2, array: true }
        klass = Class.new(ActiveRecord::Base) do
          def self.name; "Basket"; end
          self.table_name = "baskets"
          validates_column_limit_of :sizes
        end

        assert_predicate klass.new(sizes: [MAX_TWO_BYTE_SIGNED + 1]), :valid?
      ensure
        @connection.drop_table :baskets, if_exists: true
      end
    end

    if current_adapter?(:SQLite3Adapter, :PostgreSQLAdapter)
      def test_text_without_a_reported_limit_is_skipped
        assert_nil Ledger.columns_hash["notes"].limit
        Ledger.validates_column_limit_of :notes

        assert_predicate Ledger.new(notes: "n" * 100_000), :valid?
      end

      def test_column_without_a_limit_does_not_serialize
        @connection.create_table(:blobs, force: true) { |t| t.text :body }
        raising_type = Class.new(ActiveModel::Type::String) do
          def serialize(_value)
            raise "serialize must not run when the column reports no limit"
          end
        end
        klass = Class.new(ActiveRecord::Base) do
          self.table_name = "blobs"
          attribute :body, raising_type.new
          validates_column_limit_of :body
        end

        assert_predicate klass.new(body: "anything"), :valid?
      ensure
        @connection.drop_table :blobs, if_exists: true
      end
    end

    if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
      def test_text_byte_limit_is_enforced
        assert_equal 65_535, Ledger.columns_hash["notes"].limit
        Ledger.validates_column_limit_of :notes

        assert_predicate Ledger.new(notes: "n" * 65_535), :valid?
        assert_not_predicate Ledger.new(notes: "n" * 65_536), :valid?
      end

      def test_unsigned_integer_uses_the_unsigned_range
        @connection.create_table(:counters, force: true) do |t|
          t.integer :hits, limit: 1, unsigned: true
        end
        counter = Class.new(ActiveRecord::Base) do
          def self.name; "Counter"; end
          self.table_name = "counters"
          validates_column_limit_of :hits
        end

        assert_predicate counter.new(hits: 255), :valid?
        assert_not_predicate counter.new(hits: 256), :valid?

        below = counter.new(hits: -1)
        assert_not_predicate below, :valid?
        assert_equal ["is too small (minimum is 0)"], below.errors[:hits]
      ensure
        @connection.drop_table :counters, if_exists: true
      end

      def test_bit_column_is_skipped
        @connection.create_table(:flags, force: true) { |t| t.column :bits, "bit(8)" }
        klass = Class.new(ActiveRecord::Base) do
          self.table_name = "flags"
          validates_column_limit_of :bits
        end

        # bit(8) reports limit 8 as a :binary column, but the 8 is bits, not
        # bytes, so the validator declines to measure it rather than mislead.
        assert_predicate klass.new(bits: "0123456789"), :valid?
      ensure
        @connection.drop_table :flags, if_exists: true
      end

      def test_unsigned_decimal_uses_the_unsigned_range
        @connection.create_table(:prices, force: true) do |t|
          t.decimal :amount, precision: 5, scale: 2, unsigned: true
        end
        price = Class.new(ActiveRecord::Base) do
          def self.name; "Price"; end
          self.table_name = "prices"
          validates_column_limit_of :amount
        end

        assert_predicate price.new(amount: "10.0"), :valid?

        below = price.new(amount: "-10.0")
        assert_not_predicate below, :valid?
        assert_equal ["is too small (minimum is 0.0)"], below.errors[:amount]
      ensure
        @connection.drop_table :prices, if_exists: true
      end
    end
  end
end
