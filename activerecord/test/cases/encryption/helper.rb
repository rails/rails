# frozen_string_literal: true

require "cases/helper"
require "benchmark/ips"

class ActiveRecord::Fixture
  prepend ActiveRecord::Encryption::EncryptedFixtures
end

module ActiveRecord::Encryption
  module EncryptionHelpers
    def assert_encrypted_attribute(model, attribute_name, expected_value)
      encrypted_content = model.ciphertext_for(attribute_name)
      assert_not_equal expected_value, encrypted_content
      assert_equal expected_value, model.public_send(attribute_name)
      assert_equal expected_value, model.reload.public_send(attribute_name) unless model.new_record?
    end

    def assert_invalid_key_cant_read_attribute(model, attribute_name)
      if model.type_for_attribute(attribute_name).key_provider.present?
        assert_invalid_key_cant_read_attribute_with_custom_key_provider(model, attribute_name)
      else
        assert_invalid_key_cant_read_attribute_with_default_key_provider(model, attribute_name)
      end
    end

    def assert_not_encrypted_attribute(model, attribute_name, expected_value)
      assert_equal expected_value, model.send(attribute_name)
      assert_equal expected_value, model.ciphertext_for(attribute_name)
    end

    def assert_encrypted_record(model)
      encrypted_attributes = model.class.encrypted_attributes.find_all { |attribute_name| model.send(attribute_name).present? }
      assert_not encrypted_attributes.empty?, "The model has no encrypted attributes with content to check (they are all blank)"

      encrypted_attributes.each do |attribute_name|
        assert_encrypted_attribute model, attribute_name, model.send(attribute_name)
      end
    end

    def assert_encryptor_works_with(key_provider)
      encryptor = ActiveRecord::Encryption::Encryptor.new

      encrypted_message = encryptor.encrypt("some text", key_provider: key_provider)
      assert_equal "some text", encryptor.decrypt(encrypted_message, key_provider: key_provider)
    end

    private
      def build_keys(count = 3)
        count.times.collect do |index|
          password = "some secret #{index}"
          secret = ActiveRecord::Encryption.key_generator.derive_key_from(password)
          ActiveRecord::Encryption::Key.new(secret)
        end
      end

      def with_key_provider(key_provider, &block)
        ActiveRecord::Encryption.with_encryption_context key_provider: key_provider, &block
      end

      def with_envelope_encryption(&block)
        @envelope_encryption_key_provider ||= ActiveRecord::Encryption::EnvelopeEncryptionKeyProvider.new
        with_key_provider @envelope_encryption_key_provider, &block
      end

      def create_unencrypted_book_ignoring_case(name:)
        book = ActiveRecord::Encryption.without_encryption do
          EncryptedBookThatIgnoresCase.create!(name: name)
        end

        # Skip type casting to simulate an upcase value. Not supported in AR without using private apis
        EncryptedBookThatIgnoresCase.connection.execute <<~SQL
          UPDATE encrypted_books SET name = '#{name}' WHERE id = #{book.id};
        SQL

        book.reload
      end

      def assert_invalid_key_cant_read_attribute_with_default_key_provider(model, attribute_name)
        model.reload

        ActiveRecord::Encryption.with_encryption_context key_provider: ActiveRecord::Encryption::DerivedSecretKeyProvider.new("a different 256 bits key for now") do
          assert_raises ActiveRecord::Encryption::Errors::Decryption do
            model.public_send(attribute_name)
          end
        end
      end

      def assert_invalid_key_cant_read_attribute_with_custom_key_provider(model, attribute_name)
        attribute_type = model.type_for_attribute(attribute_name)

        model.reload

        attribute_type.key_provider.key = ActiveRecord::Encryption::Key.derive_from "other custom attribute secret"

        assert_raises ActiveRecord::Encryption::Errors::Decryption do
          model.public_send(attribute_name)
        end
      end
  end

  module PerformanceHelpers
    BENCHMARK_DURATION = 1
    BENCHMARK_WARMUP = 1
    BASELINE_LABEL = "Baseline"
    CODE_TO_TEST_LABEL = "Code"

    # Usage:
    #
    #     baseline = -> { <some baseline code> }
    #
    #     assert_slower_by_at_most 2, baseline: baseline do
    #       <the code you want to compare against the baseline>
    #     end
    def assert_slower_by_at_most(threshold_factor, baseline:, baseline_label: BASELINE_LABEL, code_to_test_label: CODE_TO_TEST_LABEL, duration: BENCHMARK_DURATION, quiet: false, &block_to_test)
      GC.start

      result = nil
      output, error = capture_io do
        result = Benchmark.ips do |x|
          x.config(time: duration, warmup: BENCHMARK_WARMUP)
          x.report(code_to_test_label, &block_to_test)
          x.report(baseline_label, &baseline)
          x.compare!
        end
      end

      puts "#{output}#{error}" unless quiet

      baseline_result = result.entries.find { |entry| entry.label == baseline_label }
      code_to_test_result = result.entries.find { |entry| entry.label == code_to_test_label }

      times_slower = baseline_result.ips / code_to_test_result.ips

      assert times_slower < threshold_factor, "Expecting #{threshold_factor} times slower at most, but got #{times_slower} times slower"
    end
  end
end

class ActiveRecord::EncryptionTestCase < ActiveRecord::TestCase
  include ActiveRecord::Encryption::EncryptionHelpers, ActiveRecord::Encryption::PerformanceHelpers
  # , PerformanceHelpers

  ENCRYPTION_ATTRIBUTES_TO_RESET = %i[ primary_key deterministic_key key_derivation_salt store_key_references
    key_derivation_salt support_unencrypted_data encrypt_fixtures ]

  setup do
    ENCRYPTION_ATTRIBUTES_TO_RESET.each do |property|
      instance_variable_set "@_original_#{property}", ActiveRecord::Encryption.config.public_send(property)
    end
    ActiveRecord::Encryption.config.previous_schemes.clear
    ActiveRecord::Encryption.encrypted_attribute_declaration_listeners&.clear
  end

  teardown do
    ENCRYPTION_ATTRIBUTES_TO_RESET.each do |property|
      ActiveRecord::Encryption.config.public_send("#{property}=", instance_variable_get("@_original_#{property}"))
    end
  end
end
