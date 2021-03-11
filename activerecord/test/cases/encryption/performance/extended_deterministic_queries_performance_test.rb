# frozen_string_literal: true

require "cases/encryption/helper"
require "models/book_encrypted"

class ActiveRecord::Encryption::ExtendedDeterministicQueriesPerformanceTest < ActiveRecord::TestCase
  # TODO: Is this failing only with SQLite/in memory adapter?
  test "finding with prepared statement caching by deterministically encrypted columns" do
    baseline = -> { EncryptedBook.find_by(format: "paperback") } # not encrypted

    # Performance is similar with SQL adapter
    assert_slower_by_at_most 1.6, baseline: baseline, duration: 2 do
      EncryptedBook.find_by(name: "Agile Web Development with Rails") # encrypted, deterministic
    end
  end

  test "finding without prepared statement caching by encrypted columns (deterministic)" do
    baseline = -> { EncryptedBook.where("id > 0").find_by(format: "paperback") } # not encrypted

    # Overhead is 1.1 with SQL
    assert_slower_by_at_most 1.3, baseline: baseline, duration: 2 do
      EncryptedBook.where("id > 0").find_by(name: "Agile Web Development with Rails") # encrypted, deterministic
    end
  end
end
