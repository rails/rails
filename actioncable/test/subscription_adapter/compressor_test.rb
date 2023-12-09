# frozen_string_literal: true

require "test_helper"

class ActionCable::SubscriptionAdapter::CompressorTest < ActionCable::TestCase
  SCHEMA_VERSION = ActionCable::SubscriptionAdapter::Compressor::SCHEMA_VERSION

  setup do
    @compressor = ActionCable::SubscriptionAdapter::Compressor.new
    @uncompressed_data = "hello" * 1000
    @compressed_data = @compressor.compress(@uncompressed_data)
  end

  test "#compress returns uncompressed data if it's smaller than the threshold" do
    assert @compressor.compress("hello").start_with?("#{SCHEMA_VERSION}/0/")
  end

  test "#compress returns compressed data if it's larger than the threshold" do
    assert @compressor.compress(@uncompressed_data).start_with?("#{SCHEMA_VERSION}/1/")
  end

  test "#decompress returns uncompressed data if it's not compressed" do
    assert_equal "hello", @compressor.decompress("#{SCHEMA_VERSION}/0/hello")
  end

  test "#decompress returns uncompressed data if it's compressed" do
    assert_equal @uncompressed_data, @compressor.decompress(@compressed_data)
  end

  test "#decompress returns original data if schema is not valid" do
    assert_equal "hello", @compressor.decompress("hello")
  end
end
