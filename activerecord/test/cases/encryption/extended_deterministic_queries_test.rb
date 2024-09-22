# frozen_string_literal: true

require "cases/encryption/helper"
require "models/book_encrypted"

class ActiveRecord::Encryption::ExtendedDeterministicQueriesTest < ActiveRecord::EncryptionTestCase
  setup do
    ActiveRecord::Encryption.config.support_unencrypted_data = true
  end

  test "Finds records when data is unencrypted" do
    UnencryptedBook.create!(name: "Dune")
    assert EncryptedBook.find_by(name: "Dune") # core
    assert EncryptedBook.where("id > 0").find_by(name: "Dune") # relation
  end

  test "Finds records when data is encrypted" do
    EncryptedBook.create!(name: "Dune")
    assert EncryptedBook.find_by(name: "Dune") # core
    assert EncryptedBook.where("id > 0").find_by(name: "Dune") # relation
  end

  test "WHERE queries on encrypted fields return the appropriate records with a mix of unencrypted and encrypted data" do
    enc_a1 = EncryptedBook.create!(name: "A")
    enc_b1 = EncryptedBook.create!(name: "B")
    unenc_a = UnencryptedBook.create!(name: "A")
    unenc_b = UnencryptedBook.create!(name: "B")
    enc_a2 = EncryptedBook.find(unenc_a.id)
    enc_b2 = EncryptedBook.find(unenc_b.id)

    assert EncryptedBook.where(name: "A").include?(enc_a1)
    assert EncryptedBook.where(name: "A").exclude?(enc_b1)
    assert EncryptedBook.where(name: "A").include?(enc_a2)
    assert EncryptedBook.where(name: "A").exclude?(enc_b2)

    assert EncryptedBook.where(name: "A").to_sql.include?("IN") # at risk of testing an implementation detail
  end

  test "WHERE NOT queries on encrypted fields return the appropriate records with a mix of unencrypted and encrypted data" do
    enc_a1 = EncryptedBook.create!(name: "A")
    enc_b1 = EncryptedBook.create!(name: "B")
    unenc_a = UnencryptedBook.create!(name: "A")
    unenc_b = UnencryptedBook.create!(name: "B")
    enc_a2 = EncryptedBook.find(unenc_a.id)
    enc_b2 = EncryptedBook.find(unenc_b.id)

    assert EncryptedBook.where.not(name: "A").include?(enc_b1)
    assert EncryptedBook.where.not(name: "A").exclude?(enc_a1)
    assert EncryptedBook.where.not(name: "A").include?(enc_b2)
    # FAILS! The query should return all records where name is NOT "A", but it returns the `enc_a2` record, which has name "A".
    assert EncryptedBook.where.not(name: "A").exclude?(enc_a2)

    # assert EncryptedBook.where.not(name: "A").to_sql.include?("NOT IN") # at risk of testing an implementation detail
  end

  test "Works well with downcased attributes" do
    EncryptedBookWithDowncaseName.create! name: "Dune"
    assert EncryptedBookWithDowncaseName.find_by(name: "DUNE")
  end

  test "Works well with string attribute names" do
    UnencryptedBook.create! "name" => "Dune"
    assert EncryptedBook.find_by("name" => "Dune")
  end

  test "find_or_create_by works" do
    EncryptedBook.find_or_create_by!(name: "Dune")
    assert EncryptedBook.find_by(name: "Dune")

    EncryptedBook.find_or_create_by!(name: "Dune")
    assert EncryptedBook.find_by(name: "Dune")
  end

  test "does not mutate arguments" do
    props = { name: "Dune" }

    assert_equal "Dune", EncryptedBook.find_or_initialize_by(props).name
    assert_equal "Dune", props[:name]
  end

  test "where(...).first_or_create works" do
    EncryptedBook.where(name: "Dune").first_or_create
    assert EncryptedBook.exists?(name: "Dune")
  end

  test "exists?(...) works" do
    EncryptedBook.create! name: "Dune"
    assert EncryptedBook.exists?(name: "Dune")
  end

  test "If support_unencrypted_data is opted out at the attribute level, cannot find unencrypted data" do
    UnencryptedBook.create! name: "Dune"
    assert_nil EncryptedBookWithUnencryptedDataOptedOut.find_by(name: "Dune") # core
    assert_nil EncryptedBookWithUnencryptedDataOptedOut.where("id > 0").find_by(name: "Dune") # relation
  end

  test "If support_unencrypted_data is opted out at the attribute level, can find encrypted data" do
    EncryptedBook.create! name: "Dune"
    assert EncryptedBookWithUnencryptedDataOptedOut.find_by(name: "Dune") # core
    assert EncryptedBookWithUnencryptedDataOptedOut.where("id > 0").find_by(name: "Dune") # relation
  end

  test "If support_unencrypted_data is opted in at the attribute level, can find unencrypted data" do
    UnencryptedBook.create! name: "Dune"
    assert EncryptedBookWithUnencryptedDataOptedIn.find_by(name: "Dune") # core
    assert EncryptedBookWithUnencryptedDataOptedIn.where("id > 0").find_by(name: "Dune") # relation
  end

  test "If support_unencrypted_data is opted in at the attribute level, can find encrypted data" do
    EncryptedBook.create! name: "Dune"
    assert EncryptedBookWithUnencryptedDataOptedIn.find_by(name: "Dune") # core
    assert EncryptedBookWithUnencryptedDataOptedIn.where("id > 0").find_by(name: "Dune") # relation
  end
end
