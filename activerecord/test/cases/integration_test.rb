
require "cases/helper"
require "models/company"
require "models/developer"
require "models/computer"
require "models/owner"
require "models/pet"

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
    assert_equal "1", client.to_param
  end

  def test_to_param_class_method
    firm = Firm.find(4)
    assert_equal "4-flamboyant-software", firm.to_param
  end

  def test_to_param_class_method_truncates_words_properly
    firm = Firm.find(4)
    firm.name << ", Inc."
    assert_equal "4-flamboyant-software", firm.to_param
  end

  def test_to_param_class_method_truncates_after_parameterize
    firm = Firm.find(4)
    firm.name = "Huey, Dewey, & Louie LLC"
    #               123456789T123456789v
    assert_equal "4-huey-dewey-louie-llc", firm.to_param
  end

  def test_to_param_class_method_truncates_after_parameterize_with_hyphens
    firm = Firm.find(4)
    firm.name = "Door-to-Door Wash-n-Fold Service"
    #               123456789T123456789v
    assert_equal "4-door-to-door-wash-n", firm.to_param
  end

  def test_to_param_class_method_truncates
    firm = Firm.find(4)
    firm.name = "a " * 100
    assert_equal "4-a-a-a-a-a-a-a-a-a-a", firm.to_param
  end

  def test_to_param_class_method_truncates_edge_case
    firm = Firm.find(4)
    firm.name = "David HeinemeierHansson"
    assert_equal "4-david", firm.to_param
  end

  def test_to_param_class_method_truncates_case_shown_in_doc
    firm = Firm.find(4)
    firm.name = "David Heinemeier Hansson"
    assert_equal "4-david-heinemeier", firm.to_param
  end

  def test_to_param_class_method_squishes
    firm = Firm.find(4)
    firm.name = "ab \n" * 100
    assert_equal "4-ab-ab-ab-ab-ab-ab-ab", firm.to_param
  end

  def test_to_param_class_method_multibyte_character
    firm = Firm.find(4)
    firm.name = "戦場ヶ原 ひたぎ"
    assert_equal "4", firm.to_param
  end

  def test_to_param_class_method_uses_default_if_blank
    firm = Firm.find(4)
    firm.name = nil
    assert_equal "4", firm.to_param
    firm.name = " "
    assert_equal "4", firm.to_param
  end

  def test_to_param_class_method_uses_default_if_not_persisted
    firm = Firm.new(name: "Fancy Shirts")
    assert_equal nil, firm.to_param
  end

  def test_to_param_with_no_arguments
    assert_equal "Firm", Firm.to_param
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
    assert_equal "developers/#{dev.id}-#{dev.updated_at.utc.to_s(:usec)}", dev.cache_key
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

    travel(1.second) do
      assert pet.touch
    end
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
    assert_equal "developers/#{dev.id}-#{dev.updated_on.utc.to_s(:usec)}", dev.cache_key
  end

  def test_cache_key_for_newer_updated_at
    dev = Developer.first
    dev.updated_at += 3600
    assert_equal "developers/#{dev.id}-#{dev.updated_at.utc.to_s(:usec)}", dev.cache_key
  end

  def test_cache_key_for_newer_updated_on
    dev = Developer.first
    dev.updated_on += 3600
    assert_equal "developers/#{dev.id}-#{dev.updated_on.utc.to_s(:usec)}", dev.cache_key
  end

  def test_cache_key_format_is_precise_enough
    skip("Subsecond precision is not supported") unless subsecond_precision_supported?
    dev = Developer.first
    key = dev.cache_key
    dev.touch
    assert_not_equal key, dev.cache_key
  end

  def test_cache_key_format_is_not_too_precise
    skip("Subsecond precision is not supported") unless subsecond_precision_supported?
    dev = Developer.first
    dev.touch
    key = dev.cache_key
    assert_equal key, dev.reload.cache_key
  end

  def test_named_timestamps_for_cache_key
    owner = owners(:blackbeard)
    assert_equal "owners/#{owner.id}-#{owner.happy_at.utc.to_s(:usec)}", owner.cache_key(:updated_at, :happy_at)
  end

  def test_cache_key_when_named_timestamp_is_nil
    owner = owners(:blackbeard)
    owner.happy_at = nil
    assert_equal "owners/#{owner.id}", owner.cache_key(:happy_at)
  end
end
