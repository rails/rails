# encoding: utf-8

require 'cases/helper'
require 'models/company'
require 'models/developer'
require 'models/computer'
require 'models/owner'
require 'models/pet'

class IntegrationTest < ActiveRecord::TestCase
  fixtures :companies, :developers, :owners, :pets

  def test_to_param_should_return_string
    assert_kind_of String, Client.first.to_param
  end

  def test_to_param_returns_nil_if_not_persisted
    client = Client.new
    assert_equal nil, client.to_param
  end

  def test_to_param_returns_id_if_not_persisted_but_id_is_set
    client = Client.new
    client.id = 1
    assert_equal '1', client.to_param
  end

  def test_to_param_class_method
    firm = Firm.find(4)
    assert_equal '4-flamboyant-software', firm.to_param
  end

  def test_to_param_class_method_truncates
    firm = Firm.find(4)
    firm.name = 'a ' * 100
    assert_equal '4-a-a-a-a-a-a-a-a-a', firm.to_param
  end

  def test_to_param_class_method_truncates_edge_case
    firm = Firm.find(4)
    firm.name = 'David HeinemeierHansson'
    assert_equal '4-david', firm.to_param
  end

  def test_to_param_class_method_squishes
    firm = Firm.find(4)
    firm.name = "ab \n" * 100
    assert_equal '4-ab-ab-ab-ab-ab-ab', firm.to_param
  end

  def test_to_param_class_method_multibyte_character
    firm = Firm.find(4)
    firm.name = "戦場ヶ原 ひたぎ"
    assert_equal '4', firm.to_param
  end

  def test_to_param_class_method_uses_default_if_blank
    firm = Firm.find(4)
    firm.name = nil
    assert_equal '4', firm.to_param
    firm.name = ' '
    assert_equal '4', firm.to_param
  end

  def test_to_param_class_method_uses_default_if_not_persisted
    firm = Firm.new(name: 'Fancy Shirts')
    assert_equal nil, firm.to_param
  end

  def test_to_param_with_no_arguments
    assert_equal 'Firm', Firm.to_param
  end

  def test_cache_key_for_existing_record_is_not_timezone_dependent
    utc_key = Developer.first.cache_key

    with_timezone_config zone: "EST" do
      est_key = Developer.first.cache_key
      assert_equal utc_key, est_key
    end
  end

  def test_cache_key_format_for_existing_record_with_updated_at
    dev = Developer.first
    assert_equal "developers/#{dev.id}-#{dev.updated_at.utc.to_s(:nsec)}", dev.cache_key
  end

  def test_cache_key_format_for_existing_record_with_updated_at_and_custom_cache_timestamp_format
    dev = CachedDeveloper.first
    assert_equal "cached_developers/#{dev.id}-#{dev.updated_at.utc.to_s(:number)}", dev.cache_key
  end

  def test_cache_key_changes_when_child_touched
    owner = owners(:blackbeard)
    pet   = pets(:parrot)

    owner.update_column :updated_at, Time.current
    key = owner.cache_key

    assert pet.touch
    assert_not_equal key, owner.reload.cache_key
  end

  def test_cache_key_format_for_existing_record_with_nil_updated_timestamps
    dev = Developer.first
    dev.update_columns(updated_at: nil, updated_on: nil)
    assert_match(/\/#{dev.id}$/, dev.cache_key)
  end

  def test_cache_key_for_updated_on
    dev = Developer.first
    dev.updated_at = nil
    assert_equal "developers/#{dev.id}-#{dev.updated_on.utc.to_s(:nsec)}", dev.cache_key
  end

  def test_cache_key_for_newer_updated_at
    dev = Developer.first
    dev.updated_at += 3600
    assert_equal "developers/#{dev.id}-#{dev.updated_at.utc.to_s(:nsec)}", dev.cache_key
  end

  def test_cache_key_for_newer_updated_on
    dev = Developer.first
    dev.updated_on += 3600
    assert_equal "developers/#{dev.id}-#{dev.updated_on.utc.to_s(:nsec)}", dev.cache_key
  end

  def test_cache_key_format_is_precise_enough
    dev = Developer.first
    key = dev.cache_key
    dev.touch
    assert_not_equal key, dev.cache_key
  end

  def test_named_timestamps_for_cache_key
    owner = owners(:blackbeard)
    assert_equal "owners/#{owner.id}-#{owner.happy_at.utc.to_s(:nsec)}", owner.cache_key(:updated_at, :happy_at)
  end
end
