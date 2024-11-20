# frozen_string_literal: true

require "cases/helper"
require "models/admin"
require "models/admin/user"
require "models/admin/user_json"
require "models/account"

class StoreTest < ActiveRecord::TestCase
  fixtures :'admin/users'

  setup do
    @john = Admin::User.create!(
      name: "John Doe", color: "black", remember_login: true,
      height: "tall", is_a_good_guy: true,
      parent_name: "Quinn", partner_name: "Dallas",
      partner_birthday: "1997-11-1"
    )
  end

  test "reading store attributes through accessors" do
    assert_equal "black", @john.color
    assert_nil @john.homepage
  end

  test "writing store attributes through accessors" do
    @john.color = "red"
    @john.homepage = "37signals.com"

    assert_equal "red", @john.color
    assert_equal "37signals.com", @john.homepage
  end

  test "writing store attributes does not update unchanged value" do
    admin_user = Admin::User.new(homepage: nil)
    admin_user.homepage = nil
    assert_equal({}, admin_user.settings)
  end

  test "reading store attributes through accessors with prefix" do
    assert_equal "Quinn", @john.parent_name
    assert_nil @john.parent_birthday
    assert_equal "Dallas", @john.partner_name
    assert_equal "1997-11-1", @john.partner_birthday
  end

  test "writing store attributes through accessors with prefix" do
    @john.partner_name = "River"
    @john.partner_birthday = "1999-2-11"

    assert_equal "River", @john.partner_name
    assert_equal "1999-2-11", @john.partner_birthday
  end

  test "accessing attributes not exposed by accessors" do
    @john.settings[:icecream] = "graeters"
    @john.save

    assert_equal "graeters", @john.reload.settings[:icecream]
  end

  test "overriding a read accessor" do
    @john.settings[:phone_number] = "1234567890"

    assert_equal "(123) 456-7890", @john.phone_number
  end

  test "overriding a read accessor using super" do
    @john.settings[:color] = nil

    assert_equal "red", @john.color
  end

  test "updating the store will mark it as changed" do
    @john.color = "red"
    assert_predicate @john, :settings_changed?
  end

  test "updating the store populates the changed array correctly" do
    @john.color = "red"
    assert_equal "black", @john.settings_change[0]["color"]
    assert_equal "red", @john.settings_change[1]["color"]
  end

  test "updating the store won't mark it as changed if an attribute isn't changed" do
    @john.color = @john.color
    assert_not_predicate @john, :settings_changed?
  end

  test "updating the store will mark accessor as changed" do
    @john.color = "red"
    assert_predicate @john, :color_changed?
  end

  test "new record and no accessors changes" do
    user = Admin::User.new
    assert_not user.color_changed?
    assert_nil user.color_was
    assert_nil user.color_change

    user.color = "red"
    assert_predicate user, :color_changed?
    assert_nil user.color_was
    assert_equal "red", user.color_change[1]
  end

  test "updating the store won't mark accessor as changed if the whole store was updated" do
    @john.settings = { color: @john.color, some: "thing" }
    assert_predicate @john, :settings_changed?
    assert_not @john.color_changed?
  end

  test "updating the store and changing it back won't mark accessor as changed" do
    @john.color = "red"
    assert_equal "black", @john.color_was
    @john.color = "black"
    assert_not_predicate @john, :settings_changed?
    assert_not_predicate @john, :color_changed?
  end

  test "updating the store populates the accessor changed array correctly" do
    @john.color = "red"
    assert_equal "black", @john.color_was
    assert_equal "black", @john.color_change[0]
    assert_equal "red", @john.color_change[1]
  end

  test "updating the store won't mark accessor as changed if the value isn't changed" do
    @john.color = @john.color
    assert_not @john.color_changed?
  end

  test "nullifying the store mark accessor as changed" do
    color = @john.color
    @john.settings = nil
    assert_predicate @john, :color_changed?
    assert_equal color, @john.color_was
    assert_equal [color, nil], @john.color_change
  end

  test "dirty methods for suffixed accessors" do
    @john.configs[:two_factor_auth] = true
    assert_predicate @john, :two_factor_auth_configs_changed?
    assert_nil @john.two_factor_auth_configs_was
    assert_equal [nil, true], @john.two_factor_auth_configs_change
  end

  test "dirty methods for prefixed accessors" do
    @john.spouse[:name] = "Lena"
    assert_predicate @john, :partner_name_changed?
    assert_equal "Dallas", @john.partner_name_was
    assert_equal ["Dallas", "Lena"], @john.partner_name_change
  end

  test "saved changes tracking for accessors" do
    @john.spouse[:name] = "Lena"
    assert_predicate @john, :partner_name_changed?

    @john.save!
    assert_not @john.partner_name_change
    assert_predicate @john, :saved_change_to_partner_name?
    assert_equal ["Dallas", "Lena"], @john.saved_change_to_partner_name
    assert_equal "Dallas", @john.partner_name_before_last_save
  end

  test "saved changes tracking for accessors with json column" do
    if current_adapter?(:Mysql2Adapter, :TrilogyAdapter) && ActiveRecord::Base.lease_connection.mariadb?
      skip "MariaDB doesn't support JSON store_accessor"
    end
    @john.enable_friend_requests = true
    assert_predicate @john, :enable_friend_requests_changed?

    @john.save!
    assert_not @john.enable_friend_requests_change
    assert_predicate @john, :saved_change_to_enable_friend_requests?
    assert_equal [nil, true], @john.saved_change_to_enable_friend_requests
    # Make a second change to test key_before_last_save
    @john.enable_friend_requests = false
    @john.save
    assert_equal true, @john.enable_friend_requests_before_last_save
  end

  test "object initialization with not nullable column" do
    assert_equal true, @john.remember_login
  end

  test "writing with not nullable column" do
    @john.remember_login = false
    assert_equal false, @john.remember_login
  end

  test "overriding a write accessor" do
    @john.phone_number = "(123) 456-7890"

    assert_equal "1234567890", @john.settings[:phone_number]
  end

  test "overriding a write accessor using super" do
    @john.color = "yellow"

    assert_equal "blue", @john.color
  end

  test "preserve store attributes data in HashWithIndifferentAccess format without any conversion" do
    @john.json_data = ActiveSupport::HashWithIndifferentAccess.new(:height => "tall", "weight" => "heavy")
    @john.height = "low"
    assert_equal true, @john.json_data.instance_of?(ActiveSupport::HashWithIndifferentAccess)
    assert_equal "low", @john.json_data[:height]
    assert_equal "low", @john.json_data["height"]
    assert_equal "heavy", @john.json_data[:weight]
    assert_equal "heavy", @john.json_data["weight"]
  end

  test "serialize stored nested attributes" do
    user = Admin::User.find_by_name("Jamis")
    user.update(settings: { "color" => { "jenny" => "blue" }, homepage: "rails" })

    assert_equal true, user.settings.instance_of?(ActiveSupport::HashWithIndifferentAccess)
    assert_equal "blue", user.settings[:color][:jenny]
    assert_equal "blue", user.color[:jenny]
  end

  test "store takes precedence when updating store and accessor" do
    user = Admin::User.find_by_name("Jamis")
    user.update(settings: { homepage: "rails" }, homepage: "not rails")

    assert_equal "rails", user.settings[:homepage]
    assert_equal "rails", user.homepage
  end

  def test_convert_store_attributes_from_Hash_to_HashWithIndifferentAccess_saving_the_data_and_access_attributes_indifferently
    user = Admin::User.find_by_name("Jamis")
    assert_equal "symbol",  user.settings[:symbol]
    assert_equal "symbol",  user.settings["symbol"]
    assert_equal "string",  user.settings[:string]
    assert_equal "string",  user.settings["string"]
    assert_equal true,      user.settings.instance_of?(ActiveSupport::HashWithIndifferentAccess)

    user.height = "low"
    assert_equal "symbol",  user.settings[:symbol]
    assert_equal "symbol",  user.settings["symbol"]
    assert_equal "string",  user.settings[:string]
    assert_equal "string",  user.settings["string"]
    assert_equal true,      user.settings.instance_of?(ActiveSupport::HashWithIndifferentAccess)
  end

  test "convert store attributes from any format other than Hash or HashWithIndifferentAccess losing the data" do
    @john.json_data = "somedata"
    @john.height = "low"
    assert_equal true, @john.json_data.instance_of?(ActiveSupport::HashWithIndifferentAccess)
    assert_equal "low", @john.json_data[:height]
    assert_equal "low", @john.json_data["height"]
    assert_equal false, @john.json_data.delete_if { |k, v| k == "height" }.any?
  end

  test "reading store attributes through accessors encoded with JSON" do
    assert_equal "tall", @john.height
    assert_nil @john.weight
  end

  test "writing store attributes through accessors encoded with JSON" do
    @john.height = "short"
    @john.weight = "heavy"

    assert_equal "short", @john.height
    assert_equal "heavy", @john.weight
  end

  test "accessing attributes not exposed by accessors encoded with JSON" do
    @john.json_data["somestuff"] = "somecoolstuff"
    @john.save

    assert_equal "somecoolstuff", @john.reload.json_data["somestuff"]
  end

  test "updating the store will mark it as changed encoded with JSON" do
    @john.height = "short"
    assert_predicate @john, :json_data_changed?
  end

  test "object initialization with not nullable column encoded with JSON" do
    assert_equal true, @john.is_a_good_guy
  end

  test "writing with not nullable column encoded with JSON" do
    @john.is_a_good_guy = false
    assert_equal false, @john.is_a_good_guy
  end

  test "all stored attributes are returned" do
    assert_equal [:color, :homepage, :favorite_food], Admin::User.stored_attributes[:settings]
  end

  test "stored_attributes are tracked per class" do
    first_model = Class.new(ActiveRecord::Base) do
      store_accessor :data, :color
    end
    second_model = Class.new(ActiveRecord::Base) do
      store_accessor :data, :width, :height
    end

    assert_equal [:color], first_model.stored_attributes[:data]
    assert_equal [:width, :height], second_model.stored_attributes[:data]
  end

  test "stored_attributes are tracked per subclass" do
    first_model = Class.new(ActiveRecord::Base) do
      store_accessor :data, :color
    end
    second_model = Class.new(first_model) do
      store_accessor :data, :width, :height
    end
    third_model = Class.new(first_model) do
      store_accessor :data, :area, :volume
    end

    assert_equal [:color], first_model.stored_attributes[:data]
    assert_equal [:color, :width, :height], second_model.stored_attributes[:data]
    assert_equal [:color, :area, :volume], third_model.stored_attributes[:data]
    assert_equal [:color], first_model.stored_attributes[:data]
  end

  test "YAML coder initializes the store when a Nil value is given" do
    assert_equal({}, @john.params)
  end

  test "dump, load and dump again a model" do
    dumped = YAML.dump(@john)
    loaded = YAML.respond_to?(:unsafe_load) ? YAML.unsafe_load(dumped) : YAML.load(dumped)
    assert_equal @john, loaded

    second_dump = YAML.dump(loaded)
    second_loaded = YAML.respond_to?(:unsafe_load) ? YAML.unsafe_load(second_dump) : YAML.load(second_dump)
    assert_equal @john, second_loaded
  end

  test "read store attributes through accessors with default suffix" do
    @john.configs[:two_factor_auth] = true
    assert_equal true, @john.two_factor_auth_configs
  end

  test "write store attributes through accessors with default suffix" do
    @john.two_factor_auth_configs = false
    assert_equal false, @john.configs[:two_factor_auth]
  end

  test "read store attributes through accessors with custom suffix" do
    @john.configs[:login_retry] = 3
    assert_equal 3, @john.login_retry_config
  end

  test "write store attributes through accessors with custom suffix" do
    @john.login_retry_config = 5
    assert_equal 5, @john.configs[:login_retry]
  end

  test "read accessor without pre/suffix in the same store as other pre/suffixed accessors still works" do
    @john.configs[:secret_question] = "What is your high school?"
    assert_equal "What is your high school?", @john.secret_question
  end

  test "write accessor without pre/suffix in the same store as other pre/suffixed accessors still works" do
    @john.secret_question = "What was the Rails version when you first worked on it?"
    assert_equal "What was the Rails version when you first worked on it?", @john.configs[:secret_question]
  end

  test "prefix/suffix do not affect stored attributes" do
    assert_equal [:secret_question, :two_factor_auth, :login_retry], Admin::User.stored_attributes[:configs]
  end

  test "store_accessor raises an exception if the column is not either serializable or a structured type" do
    user = Class.new(Admin::User) do
      store_accessor :name, :color
    end.new

    assert_raises ActiveRecord::ConfigurationError do
      user.color
    end

    assert_raises ActiveRecord::ConfigurationError do
      user.color = "blue"
    end
  end
end
