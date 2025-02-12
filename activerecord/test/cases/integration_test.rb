# frozen_string_literal: true

require "cases/helper"
require "models/company"
require "models/developer"
require "models/computer"
require "models/owner"
require "models/pet"
require "models/cpk"

class IntegrationTest < ActiveRecord::TestCase
  fixtures :companies, :developers, :owners, :pets

  def test_to_param_should_return_string
    assert_kind_of String, Client.first.to_param
  end

  def test_to_param_returns_nil_if_not_persisted
    client = Client.new
    assert_nil client.to_param
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
    assert_nil firm.to_param
  end

  def test_to_param_with_no_arguments
    assert_equal "Firm", Firm.to_param
  end

  def test_to_param_for_a_composite_primary_key_model
    assert_equal "1_123", Cpk::Order.new(id: [1, 123]).to_param
  end

  def test_param_delimiter_changes_delimiter_used_in_to_param
    Cpk::Order.stub(:param_delimiter, ",") do
      assert_equal("1,123", Cpk::Order.new(id: [1, 123]).to_param)
    end
  end

  def test_param_delimiter_is_defined_per_class
    Cpk::Order.stub(:param_delimiter, ",") do
      Cpk::Book.stub(:param_delimiter, ";") do
        assert_equal("1,123", Cpk::Order.new(id: [1, 123]).to_param)
        assert_equal("1;123", Cpk::Book.new(id: [1, 123]).to_param)
      end
    end
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
    assert_equal "developers/#{dev.id}-#{dev.updated_at.utc.to_fs(:usec)}", dev.cache_key
  end

  def test_cache_key_format_for_existing_record_with_updated_at_and_custom_cache_timestamp_format
    dev = CachedDeveloper.first
    assert_equal "cached_developers/#{dev.id}-#{dev.updated_at.utc.to_fs(:number)}", dev.cache_key
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
    assert_equal "developers/#{dev.id}-#{dev.updated_on.utc.to_fs(:usec)}", dev.cache_key
  end

  def test_cache_key_for_newer_updated_at
    dev = Developer.first
    dev.updated_at += 3600
    assert_equal "developers/#{dev.id}-#{dev.updated_at.utc.to_fs(:usec)}", dev.cache_key
  end

  def test_cache_key_for_newer_updated_on
    dev = Developer.first
    dev.updated_on += 3600
    assert_equal "developers/#{dev.id}-#{dev.updated_on.utc.to_fs(:usec)}", dev.cache_key
  end

  def test_cache_key_format_is_precise_enough
    dev = Developer.first
    key = dev.cache_key
    travel_to dev.updated_at + 0.000001 do
      dev.touch
    end
    assert_not_equal key, dev.cache_key
  end

  def test_cache_key_format_is_not_too_precise
    dev = Developer.first
    dev.touch
    key = dev.cache_key
    assert_equal key, dev.reload.cache_key
  end

  def test_cache_version_format_is_precise_enough
    with_cache_versioning do
      dev = Developer.first
      version = dev.cache_version.to_param
      travel_to Developer.first.updated_at + 0.000001 do
        dev.touch
      end
      assert_not_equal version, dev.cache_version.to_param
    end
  end

  def test_cache_version_format_is_not_too_precise
    with_cache_versioning do
      dev = Developer.first
      dev.touch
      key = dev.cache_version.to_param
      assert_equal key, dev.reload.cache_version.to_param
    end
  end

  def test_cache_key_is_stable_with_versioning_on
    with_cache_versioning do
      developer = Developer.first
      first_key = developer.cache_key

      developer.touch
      second_key = developer.cache_key

      assert_equal first_key, second_key
    end
  end

  def test_cache_version_changes_with_versioning_on
    with_cache_versioning do
      developer     = Developer.first
      first_version = developer.cache_version

      travel 10.seconds do
        developer.touch
      end

      second_version = developer.cache_version

      assert_not_equal first_version, second_version
    end
  end

  def test_cache_key_retains_version_when_custom_timestamp_is_used
    with_cache_versioning do
      developer = Developer.first
      first_key = developer.cache_key_with_version

      travel 10.seconds do
        developer.touch
      end

      second_key = developer.cache_key_with_version

      assert_not_equal first_key, second_key
    end
  end

  def with_cache_versioning(value = true)
    @old_cache_versioning = ActiveRecord::Base.cache_versioning
    ActiveRecord::Base.cache_versioning = value
    yield
  ensure
    ActiveRecord::Base.cache_versioning = @old_cache_versioning
  end
end
