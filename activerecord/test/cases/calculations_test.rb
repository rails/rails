# frozen_string_literal: true

require "cases/helper"
require "models/book"
require "models/club"
require "models/company"
require "models/contract"
require "models/edge"
require "models/organization"
require "models/possession"
require "models/author"
require "models/topic"
require "models/reply"
require "models/numeric_data"
require "models/minivan"
require "models/speedometer"
require "models/ship_part"
require "models/treasure"
require "models/developer"
require "models/post"
require "models/comment"
require "models/rating"
require "support/stubs/strong_parameters"

class CalculationsTest < ActiveRecord::TestCase
  fixtures :companies, :accounts, :authors, :author_addresses, :topics, :speedometers, :minivans, :books, :posts, :comments

  def test_should_sum_field
    assert_equal 318, Account.sum(:credit_limit)
  end

  def test_should_sum_arel_attribute
    assert_equal 318, Account.sum(Account.arel_table[:credit_limit])
  end

  def test_should_average_field
    value = Account.average(:credit_limit)
    assert_equal 53.0, value
  end

  def test_should_average_arel_attribute
    value = Account.average(Account.arel_table[:credit_limit])
    assert_equal 53.0, value
  end

  def test_should_resolve_aliased_attributes
    assert_equal 318, Account.sum(:available_credit)
  end

  def test_should_return_decimal_average_of_integer_field
    value = Account.average(:id)
    assert_equal 3.5, value
  end

  def test_should_return_integer_average_if_db_returns_such
    ShipPart.delete_all
    ShipPart.create!(id: 3, name: "foo")
    value = ShipPart.average(:id)
    assert_equal 3, value
  end

  def test_should_return_nil_as_average
    assert_nil NumericData.average(:bank_balance)
  end

  def test_should_get_maximum_of_field
    assert_equal 60, Account.maximum(:credit_limit)
  end

  def test_should_get_maximum_of_arel_attribute
    assert_equal 60, Account.maximum(Account.arel_table[:credit_limit])
  end

  def test_should_get_maximum_of_field_with_include
    assert_equal 55, Account.where("companies.name != 'Summit'").references(:companies).includes(:firm).maximum(:credit_limit)
  end

  def test_should_get_maximum_of_arel_attribute_with_include
    assert_equal 55, Account.where("companies.name != 'Summit'").references(:companies).includes(:firm).maximum(Account.arel_table[:credit_limit])
  end

  def test_should_get_minimum_of_field
    assert_equal 50, Account.minimum(:credit_limit)
  end

  def test_should_get_minimum_of_arel_attribute
    assert_equal 50, Account.minimum(Account.arel_table[:credit_limit])
  end

  def test_should_group_by_field
    c = Account.group(:firm_id).sum(:credit_limit)
    [1, 6, 2].each do |firm_id|
      assert_includes c.keys, firm_id, "Group #{c.inspect} does not contain firm_id #{firm_id}"
    end
  end

  def test_should_group_by_arel_attribute
    c = Account.group(Account.arel_table[:firm_id]).sum(:credit_limit)
    [1, 6, 2].each do |firm_id|
      assert_includes c.keys, firm_id, "Group #{c.inspect} does not contain firm_id #{firm_id}"
    end
  end

  def test_should_group_by_multiple_fields
    c = Account.group("firm_id", :credit_limit).count(:all)
    [ [nil, 50], [1, 50], [6, 50], [6, 55], [9, 53], [2, 60] ].each { |firm_and_limit| assert_includes c.keys, firm_and_limit }
  end

  def test_should_group_by_multiple_fields_having_functions
    c = Topic.group(:author_name, "COALESCE(type, title)").count(:all)
    assert_equal 1, c[["Carl", "The Third Topic of the day"]]
    assert_equal 1, c[["Mary", "Reply"]]
    assert_equal 1, c[["David", "The First Topic"]]
    assert_equal 1, c[["Carl", "Reply"]]
  end

  def test_should_group_by_summed_field
    expected = { nil => 50, 1 => 50, 2 => 60, 6 => 105, 9 => 53 }
    assert_equal expected, Account.group(:firm_id).sum(:credit_limit)
  end

  def test_group_by_multiple_same_field
    accounts = Account.group(:firm_id)

    expected = {
      nil => 50,
      1 => 50,
      2 => 60,
      6 => 105,
      9 => 53
    }
    assert_equal expected, accounts.sum(:credit_limit)
    assert_equal expected, accounts.merge!(accounts).uniq!(:group).sum(:credit_limit)

    expected = {
      [nil, nil] => 50,
      [1, 1] => 50,
      [2, 2] => 60,
      [6, 6] => 55,
      [9, 9] => 53
    }
    message = <<-MSG.squish
      `maximum` with group by duplicated fields does no longer affect to result in Rails 6.2.
      To migrate to Rails 6.2's behavior, use `uniq!(:group)` to deduplicate group fields
      (`accounts.uniq!(:group).maximum(:credit_limit)`).
    MSG
    assert_deprecated(message) do
      assert_equal expected, accounts.merge!(accounts).maximum(:credit_limit)
    end

    expected = {
      [nil, nil, nil, nil] => 50,
      [1, 1, 1, 1] => 50,
      [2, 2, 2, 2] => 60,
      [6, 6, 6, 6] => 50,
      [9, 9, 9, 9] => 53
    }
    message = <<-MSG.squish
      `minimum` with group by duplicated fields does no longer affect to result in Rails 6.2.
      To migrate to Rails 6.2's behavior, use `uniq!(:group)` to deduplicate group fields
      (`accounts.uniq!(:group).minimum(:credit_limit)`).
    MSG
    assert_deprecated(message) do
      assert_equal expected, accounts.merge!(accounts).minimum(:credit_limit)
    end
  end

  def test_should_generate_valid_sql_with_joins_and_group
    assert_nothing_raised do
      AuditLog.joins(:developer).group(:id).count
    end
  end

  def test_should_calculate_against_given_relation
    developer = Developer.create!(name: "developer")
    developer.audit_logs.create!(message: "first log")
    developer.audit_logs.create!(message: "second log")

    c = developer.audit_logs.joins(:developer).group(:id).count

    assert_equal developer.audit_logs.count, c.size
    developer.audit_logs.each do |log|
      assert_equal 1, c[log.id]
    end
  end

  def test_should_not_use_alias_for_grouped_field
    assert_sql(/GROUP BY #{Regexp.escape(Account.connection.quote_table_name("accounts.firm_id"))}/i) do
      c = Account.group(:firm_id).order("accounts_firm_id").sum(:credit_limit)
      assert_equal [1, 2, 6, 9], c.keys.compact
    end
  end

  def test_should_order_by_grouped_field
    c = Account.group(:firm_id).order("firm_id").sum(:credit_limit)
    assert_equal [1, 2, 6, 9], c.keys.compact
  end

  def test_should_order_by_calculation
    c = Account.group(:firm_id).order("sum_credit_limit desc, firm_id").sum(:credit_limit)
    assert_equal [105, 60, 53, 50, 50], c.keys.collect { |k| c[k] }
    assert_equal [6, 2, 9, 1], c.keys.compact
  end

  def test_should_limit_calculation
    c = Account.where("firm_id IS NOT NULL").group(:firm_id).order("firm_id").limit(2).sum(:credit_limit)
    assert_equal [1, 2], c.keys.compact
  end

  def test_should_limit_calculation_with_offset
    c = Account.where("firm_id IS NOT NULL").group(:firm_id).order("firm_id").
     limit(2).offset(1).sum(:credit_limit)
    assert_equal [2, 6], c.keys.compact
  end

  def test_limit_should_apply_before_count
    accounts = Account.order(:id).limit(4)

    assert_equal 3, accounts.count(:firm_id)
    assert_equal 3, accounts.select(:firm_id).count
  end

  def test_limit_should_apply_before_count_arel_attribute
    accounts = Account.order(:id).limit(4)

    firm_id_attribute = Account.arel_table[:firm_id]
    assert_equal 3, accounts.count(firm_id_attribute)
    assert_equal 3, accounts.select(firm_id_attribute).count
  end

  def test_count_should_shortcut_with_limit_zero
    accounts = Account.limit(0)

    assert_no_queries { assert_equal 0, accounts.count }
  end

  def test_limit_is_kept
    return if current_adapter?(:OracleAdapter)

    queries = capture_sql { Account.limit(1).count }
    assert_equal 1, queries.length
    assert_match(/LIMIT/, queries.first)
  end

  def test_offset_is_kept
    return if current_adapter?(:OracleAdapter)

    queries = capture_sql { Account.offset(1).count }
    assert_equal 1, queries.length
    assert_match(/OFFSET/, queries.first)
  end

  def test_limit_with_offset_is_kept
    return if current_adapter?(:OracleAdapter)

    queries = capture_sql { Account.limit(1).offset(1).count }
    assert_equal 1, queries.length
    assert_match(/LIMIT/, queries.first)
    assert_match(/OFFSET/, queries.first)
  end

  def test_no_limit_no_offset
    queries = capture_sql { Account.count }
    assert_equal 1, queries.length
    assert_no_match(/LIMIT/, queries.first)
    assert_no_match(/OFFSET/, queries.first)
  end

  def test_count_on_invalid_columns_raises
    e = assert_raises(ActiveRecord::StatementInvalid) {
      Account.select("credit_limit, firm_name").count
    }

    assert_match %r{accounts}i, e.sql
    assert_match "credit_limit, firm_name", e.sql
  end

  def test_apply_distinct_in_count
    queries = capture_sql do
      Account.distinct.count
      Account.group(:firm_id).distinct.count
    end

    queries.each do |query|
      assert_match %r{\ASELECT(?! DISTINCT) COUNT\(DISTINCT\b}, query
    end
  end

  def test_count_with_eager_loading_and_custom_order
    posts = Post.includes(:comments).order("comments.id")
    assert_queries(1) { assert_equal 11, posts.count }
    assert_queries(1) { assert_equal 11, posts.count(:all) }
  end

  def test_count_with_eager_loading_and_custom_select_and_order
    posts = Post.includes(:comments).order("comments.id").select(:type)
    assert_queries(1) { assert_equal 11, posts.count }
    assert_queries(1) { assert_equal 11, posts.count(:all) }
  end

  def test_count_with_eager_loading_and_custom_order_and_distinct
    posts = Post.includes(:comments).order("comments.id").distinct
    assert_queries(1) { assert_equal 11, posts.count }
    assert_queries(1) { assert_equal 11, posts.count(:all) }
  end

  def test_distinct_count_all_with_custom_select_and_order
    accounts = Account.distinct.select("credit_limit % 10").order(Arel.sql("credit_limit % 10"))
    assert_queries(1) { assert_equal 3, accounts.count(:all) }
    assert_queries(1) { assert_equal 3, accounts.load.size }
  end

  def test_distinct_count_with_order_and_limit
    assert_equal 4, Account.distinct.order(:firm_id).limit(4).count
  end

  def test_distinct_count_with_order_and_offset
    assert_equal 4, Account.distinct.order(:firm_id).offset(2).count
  end

  def test_distinct_count_with_order_and_limit_and_offset
    assert_equal 4, Account.distinct.order(:firm_id).limit(4).offset(2).count
  end

  def test_distinct_joins_count_with_order_and_limit
    assert_equal 3, Account.joins(:firm).distinct.order(:firm_id).limit(3).count
  end

  def test_distinct_joins_count_with_order_and_offset
    assert_equal 3, Account.joins(:firm).distinct.order(:firm_id).offset(2).count
  end

  def test_distinct_joins_count_with_order_and_limit_and_offset
    assert_equal 3, Account.joins(:firm).distinct.order(:firm_id).limit(3).offset(2).count
  end

  def test_distinct_joins_count_with_group_by
    expected = { nil => 4, 1 => 1, 2 => 1, 4 => 1, 5 => 1, 7 => 1 }
    assert_equal expected, Post.left_joins(:comments).group(:post_id).distinct.count(:author_id)
    assert_equal expected, Post.left_joins(:comments).group(:post_id).distinct.select(:author_id).count
    assert_equal expected, Post.left_joins(:comments).group(:post_id).count("DISTINCT posts.author_id")
    assert_equal expected, Post.left_joins(:comments).group(:post_id).select("DISTINCT posts.author_id").count

    expected = { nil => 6, 1 => 1, 2 => 1, 4 => 1, 5 => 1, 7 => 1 }
    assert_equal expected, Post.left_joins(:comments).group(:post_id).distinct.count(:all)
    assert_equal expected, Post.left_joins(:comments).group(:post_id).distinct.select(:author_id).count(:all)
  end

  def test_distinct_count_with_group_by_and_order_and_limit
    assert_equal({ 6 => 2 }, Account.group(:firm_id).distinct.order("1 DESC").limit(1).count)
  end

  def test_should_group_by_summed_field_having_condition
    c = Account.group(:firm_id).having("sum(credit_limit) > 50").sum(:credit_limit)
    assert_nil        c[1]
    assert_equal 105, c[6]
    assert_equal 60,  c[2]
  end

  def test_should_group_by_summed_field_having_condition_from_select
    skip unless current_adapter?(:Mysql2Adapter, :SQLite3Adapter)
    c = Account.select("MIN(credit_limit) AS min_credit_limit").group(:firm_id).having("min_credit_limit > 50").sum(:credit_limit)
    assert_nil       c[1]
    assert_equal 60, c[2]
    assert_equal 53, c[9]
  end

  def test_should_group_by_summed_association
    c = Account.group(:firm).sum(:credit_limit)
    assert_equal 50,   c[companies(:first_firm)]
    assert_equal 105,  c[companies(:rails_core)]
    assert_equal 60,   c[companies(:first_client)]
  end

  def test_should_sum_field_with_conditions
    assert_equal 105, Account.where("firm_id = 6").sum(:credit_limit)
  end

  def test_should_return_zero_if_sum_conditions_return_nothing
    assert_equal 0, Account.where("1 = 2").sum(:credit_limit)
    assert_equal 0, companies(:rails_core).companies.where("1 = 2").sum(:id)
  end

  def test_sum_should_return_valid_values_for_decimals
    NumericData.create(bank_balance: 19.83)
    assert_equal 19.83, NumericData.sum(:bank_balance)
  end

  def test_should_return_type_casted_values_with_group_and_expression
    assert_equal 0.5, Account.group(:firm_name).sum("0.01 * credit_limit")["37signals"]
  end

  def test_should_group_by_summed_field_with_conditions
    c = Account.where("firm_id > 1").group(:firm_id).sum(:credit_limit)
    assert_nil        c[1]
    assert_equal 105, c[6]
    assert_equal 60,  c[2]
  end

  def test_should_group_by_summed_field_with_conditions_and_having
    c = Account.where("firm_id > 1").group(:firm_id).
     having("sum(credit_limit) > 60").sum(:credit_limit)
    assert_nil        c[1]
    assert_equal 105, c[6]
    assert_nil        c[2]
  end

  def test_should_group_by_fields_with_table_alias
    c = Account.group("accounts.firm_id").sum(:credit_limit)
    assert_equal 50,  c[1]
    assert_equal 105, c[6]
    assert_equal 60,  c[2]
  end

  def test_should_calculate_grouped_with_longer_field
    field = "a" * Account.connection.max_identifier_length

    Account.update_all("#{field} = credit_limit")

    c = Account.group(:firm_id).sum(field)
    assert_equal 50,  c[1]
    assert_equal 105, c[6]
    assert_equal 60,  c[2]
  end

  def test_should_calculate_with_invalid_field
    assert_equal 6, Account.calculate(:count, "*")
    assert_equal 6, Account.calculate(:count, :all)
  end

  def test_should_calculate_grouped_with_invalid_field
    c = Account.group("accounts.firm_id").count(:all)
    assert_equal 1, c[1]
    assert_equal 2, c[6]
    assert_equal 1, c[2]
  end

  def test_should_calculate_grouped_association_with_invalid_field
    c = Account.group(:firm).count(:all)
    assert_equal 1, c[companies(:first_firm)]
    assert_equal 2, c[companies(:rails_core)]
    assert_equal 1, c[companies(:first_client)]
  end

  def test_should_group_by_association_with_non_numeric_foreign_key
    Speedometer.create! id: "ABC"
    Minivan.create! id: "OMG", speedometer_id: "ABC"

    c = Minivan.group(:speedometer).count(:all)
    first_key = c.keys.first
    assert_equal Speedometer, first_key.class
    assert_equal 1, c[first_key]
  end

  def test_should_calculate_grouped_association_with_foreign_key_option
    Account.belongs_to :another_firm, class_name: "Firm", foreign_key: "firm_id"
    c = Account.group(:another_firm).count(:all)
    assert_equal 1, c[companies(:first_firm)]
    assert_equal 2, c[companies(:rails_core)]
    assert_equal 1, c[companies(:first_client)]
  end

  def test_should_calculate_grouped_by_function
    c = Company.group("UPPER(#{QUOTED_TYPE})").count(:all)
    assert_equal 2, c[nil]
    assert_equal 1, c["DEPENDENTFIRM"]
    assert_equal 5, c["CLIENT"]
    assert_equal 2, c["FIRM"]
  end

  def test_should_calculate_grouped_by_function_with_table_alias
    c = Company.group("UPPER(companies.#{QUOTED_TYPE})").count(:all)
    assert_equal 2, c[nil]
    assert_equal 1, c["DEPENDENTFIRM"]
    assert_equal 5, c["CLIENT"]
    assert_equal 2, c["FIRM"]
  end

  def test_should_not_overshadow_enumerable_sum
    assert_equal 6, [1, 2, 3].sum(&:abs)
  end

  def test_should_sum_scoped_field
    assert_equal 15, companies(:rails_core).companies.sum(:id)
  end

  def test_should_sum_scoped_field_with_from
    assert_equal Club.count, Organization.clubs.count
  end

  def test_should_sum_scoped_field_with_conditions
    assert_equal 8,  companies(:rails_core).companies.where("id > 7").sum(:id)
  end

  def test_should_group_by_scoped_field
    c = companies(:rails_core).companies.group(:name).sum(:id)
    assert_equal 7, c["Leetsoft"]
    assert_equal 8, c["Jadedpixel"]
  end

  def test_should_group_by_summed_field_through_association_and_having
    c = companies(:rails_core).companies.group(:name).having("sum(id) > 7").sum(:id)
    assert_nil      c["Leetsoft"]
    assert_equal 8, c["Jadedpixel"]
  end

  def test_should_count_selected_field_with_include
    assert_equal 6, Account.includes(:firm).distinct.count
    assert_equal 4, Account.includes(:firm).distinct.select(:credit_limit).count
    assert_equal 4, Account.includes(:firm).distinct.count("DISTINCT credit_limit")
    assert_equal 4, Account.includes(:firm).distinct.count("DISTINCT(credit_limit)")
  end

  def test_should_not_perform_joined_include_by_default
    assert_equal Account.count, Account.includes(:firm).count
    queries = capture_sql { Account.includes(:firm).count }
    assert_no_match(/join/i, queries.last)
  end

  def test_should_perform_joined_include_when_referencing_included_tables
    joined_count = Account.includes(:firm).where(companies: { name: "37signals" }).count
    assert_equal 1, joined_count
  end

  def test_should_count_scoped_select
    Account.update_all("credit_limit = NULL")
    assert_equal 0, Account.select("credit_limit").count
  end

  def test_should_count_scoped_select_with_options
    Account.update_all("credit_limit = NULL")
    Account.last.update_columns("credit_limit" => 49)
    Account.first.update_columns("credit_limit" => 51)

    assert_equal 1, Account.select("credit_limit").where("credit_limit >= 50").count
  end

  def test_should_count_manual_select_with_include
    assert_equal 6, Account.select("DISTINCT accounts.id").includes(:firm).count
  end

  def test_should_count_manual_select_with_count_all
    assert_equal 5, Account.select("DISTINCT accounts.firm_id").count(:all)
  end

  def test_should_count_with_manual_distinct_select_and_distinct
    assert_equal 4, Account.select("DISTINCT accounts.firm_id").distinct(true).count
  end

  def test_should_count_manual_select_with_group_with_count_all
    expected = { nil => 1, 1 => 1, 2 => 1, 6 => 2, 9 => 1 }
    actual = Account.select("DISTINCT accounts.firm_id").group("accounts.firm_id").count(:all)
    assert_equal expected, actual
  end

  def test_should_count_manual_with_count_all
    assert_equal 6, Account.count(:all)
  end

  def test_count_selected_arel_attribute
    assert_equal 5, Account.select(Account.arel_table[:firm_id]).count
    assert_equal 4, Account.distinct.select(Account.arel_table[:firm_id]).count
  end

  def test_count_with_column_parameter
    assert_equal 5, Account.count(:firm_id)
  end

  def test_count_with_arel_attribute
    assert_equal 5, Account.count(Account.arel_table[:firm_id])
  end

  def test_count_with_arel_star
    assert_equal 6, Account.count(Arel.star)
  end

  def test_count_with_distinct
    assert_equal 4, Account.select(:credit_limit).distinct.count
  end

  def test_count_with_aliased_attribute
    assert_equal 6, Account.count(:available_credit)
  end

  def test_count_with_column_and_options_parameter
    assert_equal 2, Account.where("credit_limit = 50 AND firm_id IS NOT NULL").count(:firm_id)
  end

  def test_should_count_field_in_joined_table
    assert_equal 5, Account.joins(:firm).count("companies.id")
    assert_equal 4, Account.joins(:firm).distinct.count("companies.id")
  end

  def test_count_arel_attribute_in_joined_table_with
    assert_equal 5, Account.joins(:firm).count(Company.arel_table[:id])
    assert_equal 4, Account.joins(:firm).distinct.count(Company.arel_table[:id])
  end

  def test_count_selected_arel_attribute_in_joined_table
    assert_equal 5, Account.joins(:firm).select(Company.arel_table[:id]).count
    assert_equal 4, Account.joins(:firm).distinct.select(Company.arel_table[:id]).count
  end

  def test_should_count_field_in_joined_table_with_group_by
    c = Account.group("accounts.firm_id").joins(:firm).count("companies.id")

    [1, 6, 2, 9].each { |firm_id| assert_includes c.keys, firm_id }
  end

  def test_should_count_field_of_root_table_with_conflicting_group_by_column
    expected = { 1 => 2, 2 => 1, 4 => 5, 5 => 2, 7 => 1 }
    assert_equal expected, Post.joins(:comments).group(:post_id).count
    assert_equal expected, Post.joins(:comments).group("comments.post_id").count
    assert_equal expected, Post.joins(:comments).group(:post_id).select("DISTINCT posts.author_id").count(:all)
  end

  def test_count_with_no_parameters_isnt_deprecated
    assert_not_deprecated { Account.count }
  end

  def test_count_with_too_many_parameters_raises
    assert_raise(ArgumentError) { Account.count(1, 2, 3) }
  end

  def test_count_with_order
    assert_equal 6, Account.order(:credit_limit).count
  end

  def test_count_with_reverse_order
    assert_equal 6, Account.order(:credit_limit).reverse_order.count
  end

  def test_count_with_where_and_order
    assert_equal 1, Account.where(firm_name: "37signals").count
    assert_equal 1, Account.where(firm_name: "37signals").order(:firm_name).count
    assert_equal 1, Account.where(firm_name: "37signals").order(:firm_name).reverse_order.count
  end

  def test_count_with_block
    assert_equal 4, Account.count { |account| account.credit_limit.modulo(10).zero? }
  end

  def test_should_sum_expression
    assert_equal 636, Account.sum("2 * credit_limit")
  end

  def test_sum_expression_returns_zero_when_no_records_to_sum
    assert_equal 0, Account.where("1 = 2").sum("2 * credit_limit")
  end

  def test_count_with_from_option
    assert_equal Company.count(:all), Company.from("companies").count(:all)
    assert_equal Account.where("credit_limit = 50").count(:all),
        Account.from("accounts").where("credit_limit = 50").count(:all)
    assert_equal Company.where(type: "Firm").count(:type),
        Company.where(type: "Firm").from("companies").count(:type)
  end

  def test_sum_with_from_option
    assert_equal Account.sum(:credit_limit), Account.from("accounts").sum(:credit_limit)
    assert_equal Account.where("credit_limit > 50").sum(:credit_limit),
        Account.where("credit_limit > 50").from("accounts").sum(:credit_limit)
  end

  def test_average_with_from_option
    assert_equal Account.average(:credit_limit), Account.from("accounts").average(:credit_limit)
    assert_equal Account.where("credit_limit > 50").average(:credit_limit),
        Account.where("credit_limit > 50").from("accounts").average(:credit_limit)
  end

  def test_minimum_with_from_option
    assert_equal Account.minimum(:credit_limit), Account.from("accounts").minimum(:credit_limit)
    assert_equal Account.where("credit_limit > 50").minimum(:credit_limit),
        Account.where("credit_limit > 50").from("accounts").minimum(:credit_limit)
  end

  def test_maximum_with_from_option
    assert_equal Account.maximum(:credit_limit), Account.from("accounts").maximum(:credit_limit)
    assert_equal Account.where("credit_limit > 50").maximum(:credit_limit),
        Account.where("credit_limit > 50").from("accounts").maximum(:credit_limit)
  end

  def test_maximum_with_not_auto_table_name_prefix_if_column_included
    Company.create!(name: "test", contracts: [Contract.new(developer_id: 7)])

    assert_equal 7, Company.includes(:contracts).maximum(:developer_id)
  end

  def test_minimum_with_not_auto_table_name_prefix_if_column_included
    Company.create!(name: "test", contracts: [Contract.new(developer_id: 7)])

    assert_equal 7, Company.includes(:contracts).minimum(:developer_id)
  end

  def test_sum_with_not_auto_table_name_prefix_if_column_included
    Company.create!(name: "test", contracts: [Contract.new(developer_id: 7)])

    assert_equal 7, Company.includes(:contracts).sum(:developer_id)
  end

  def test_from_option_with_specified_index
    edges = Edge.from("edges /*! USE INDEX(unique_edge_index) */")
    assert_equal Edge.count(:all), edges.count(:all)
    assert_equal Edge.where("sink_id < 5").count(:all), edges.where("sink_id < 5").count(:all)
  end

  def test_from_option_with_table_different_than_class
    assert_equal Account.count(:all), Company.from("accounts").count(:all)
  end

  def test_distinct_is_honored_when_used_with_count_operation_after_group
    # Count the number of authors for approved topics
    approved_topics_count = Topic.group(:approved).count(:author_name)[true]
    assert_equal approved_topics_count, 4
    # Count the number of distinct authors for approved Topics
    distinct_authors_for_approved_count = Topic.group(:approved).distinct.count(:author_name)[true]
    assert_equal distinct_authors_for_approved_count, 3
  end

  def test_pluck
    assert_equal [1, 2, 3, 4, 5], Topic.order(:id).pluck(:id)
  end

  def test_pluck_with_empty_in
    assert_queries(0) do
      assert_equal [], Topic.where(id: []).pluck(:id)
    end
  end

  def test_pluck_without_column_names
    if current_adapter?(:OracleAdapter)
      assert_equal [[1, "Firm", 1, nil, "37signals", nil, 1, nil, nil]], Company.order(:id).limit(1).pluck
    else
      assert_equal [[1, "Firm", 1, nil, "37signals", nil, 1, nil, ""]], Company.order(:id).limit(1).pluck
    end
  end

  def test_pluck_type_cast
    topic = topics(:first)
    relation = Topic.where(id: topic.id)
    assert_equal [ topic.approved ], relation.pluck(:approved)
    assert_equal [ topic.last_read ], relation.pluck(:last_read)
    assert_equal [ topic.written_on ], relation.pluck(:written_on)
  end

  def test_pluck_type_cast_with_conflict_column_names
    expected = [
      [Date.new(2004, 4, 15), "unread"],
      [Date.new(2004, 4, 15), "reading"],
      [Date.new(2004, 4, 15), "read"],
    ]
    actual = AuthorAddress.joins(author: [:topics, :books]).order(:"books.last_read")
      .where("books.last_read": [:unread, :reading, :read])
      .pluck(:"topics.last_read", :"books.last_read")

    assert_equal expected, actual
  end

  def test_pluck_type_cast_with_joins_without_table_name_qualified_column
    assert_pluck_type_cast_without_table_name_qualified_column(AuthorAddress.joins(author: :books))
  end

  def test_pluck_type_cast_with_left_joins_without_table_name_qualified_column
    assert_pluck_type_cast_without_table_name_qualified_column(AuthorAddress.left_joins(author: :books))
  end

  def test_pluck_type_cast_with_eager_load_without_table_name_qualified_column
    assert_pluck_type_cast_without_table_name_qualified_column(AuthorAddress.eager_load(author: :books))
  end

  def assert_pluck_type_cast_without_table_name_qualified_column(author_addresses)
    expected = [
      [nil, "unread"],
      ["ebook", "reading"],
      ["paperback", "read"],
    ]
    actual = author_addresses.order(:last_read)
      .where("books.last_read": [:unread, :reading, :read])
      .pluck(:format, :last_read)

    assert_equal expected, actual
  end
  private :assert_pluck_type_cast_without_table_name_qualified_column

  def test_pluck_with_type_cast_does_not_corrupt_the_query_cache
    topic = topics(:first)
    relation = Topic.where(id: topic.id)
    assert_queries 1 do
      Topic.cache do
        kind = relation.select(:written_on).load.first.read_attribute_before_type_cast(:written_on).class
        relation.pluck(:written_on)
        assert_kind_of kind, relation.select(:written_on).load.first.read_attribute_before_type_cast(:written_on)
      end
    end
  end

  def test_pluck_and_distinct
    assert_equal [50, 53, 55, 60], Account.order(:credit_limit).distinct.pluck(:credit_limit)
  end

  def test_pluck_in_relation
    company = Company.first
    contract = company.contracts.create!
    assert_equal [contract.id], company.contracts.pluck(:id)
  end

  def test_pluck_on_aliased_attribute
    assert_equal "The First Topic", Topic.order(:id).pluck(:heading).first
  end

  def test_pluck_with_serialization
    t = Topic.create!(content: { foo: :bar })
    assert_equal [{ foo: :bar }], Topic.where(id: t.id).pluck(:content)
  end

  def test_pluck_with_qualified_column_name
    assert_equal [1, 2, 3, 4, 5], Topic.order(:id).pluck("topics.id")
  end

  def test_pluck_auto_table_name_prefix
    c = Company.create!(name: "test", contracts: [Contract.new])
    assert_equal [c.id], Company.joins(:contracts).pluck(:id)
  end

  def test_pluck_if_table_included
    c = Company.create!(name: "test", contracts: [Contract.new(developer_id: 7)])
    assert_equal [c.id], Company.includes(:contracts).where("contracts.id" => c.contracts.first).pluck(:id)
  end

  def test_pluck_not_auto_table_name_prefix_if_column_joined
    company = Company.create!(name: "test", contracts: [Contract.new(developer_id: 7)])
    metadata = company.contracts.first.metadata
    assert_equal [metadata], Company.joins(:contracts).pluck(:metadata)
  end

  def test_pluck_with_selection_clause
    assert_equal [50, 53, 55, 60], Account.pluck(Arel.sql("DISTINCT credit_limit")).sort
    assert_equal [50, 53, 55, 60], Account.pluck(Arel.sql("DISTINCT accounts.credit_limit")).sort
    assert_equal [50, 53, 55, 60], Account.pluck(Arel.sql("DISTINCT(credit_limit)")).sort
    assert_equal [50 + 53 + 55 + 60], Account.pluck(Arel.sql("SUM(DISTINCT(credit_limit))"))
  end

  def test_plucks_with_ids
    assert_equal Company.all.map(&:id).sort, Company.ids.sort
  end

  def test_pluck_with_includes_limit_and_empty_result
    assert_equal [], Topic.includes(:replies).limit(0).pluck(:id)
    assert_equal [], Topic.includes(:replies).limit(1).where("0 = 1").pluck(:id)
  end

  def test_pluck_with_includes_offset
    assert_equal [5], Topic.includes(:replies).order(:id).offset(4).pluck(:id)
    assert_equal [], Topic.includes(:replies).order(:id).offset(5).pluck(:id)
  end

  def test_pluck_with_join
    assert_equal [[2, 2], [4, 4]], Reply.includes(:topic).order(:id).pluck(:id, :"topics.id")
  end

  def test_group_by_with_order_by_virtual_count_attribute
    expected = { "SpecialPost" => 1, "StiPost" => 2 }
    actual = Post.group(:type).order(:count).limit(2).maximum(:comments_count)
    assert_equal expected, actual
  end if current_adapter?(:PostgreSQLAdapter)

  def test_group_by_with_limit
    expected = { "StiPost" => 2, "SpecialPost" => 1 }
    actual = Post.includes(:comments).group(:type).order(type: :desc).limit(2).count("comments.id")
    assert_equal expected, actual
  end

  def test_group_by_with_offset
    expected = { "SpecialPost" => 1, "Post" => 8 }
    actual = Post.includes(:comments).group(:type).order(type: :desc).offset(1).count("comments.id")
    assert_equal expected, actual
  end

  def test_group_by_with_limit_and_offset
    expected = { "SpecialPost" => 1 }
    actual = Post.includes(:comments).group(:type).order(type: :desc).offset(1).limit(1).count("comments.id")
    assert_equal expected, actual
  end

  def test_group_by_with_quoted_count_and_order_by_alias
    quoted_posts_id = Post.connection.quote_table_name("posts.id")
    expected = { "SpecialPost" => 1, "StiPost" => 1, "Post" => 9 }
    actual = Post.group(:type).order("count_posts_id").count(quoted_posts_id)
    assert_equal expected, actual
  end

  def test_pluck_not_auto_table_name_prefix_if_column_included
    Company.create!(name: "test", contracts: [Contract.new(developer_id: 7)])
    ids = Company.includes(:contracts).pluck(:developer_id)
    assert_equal Company.count, ids.length
    assert_equal [7], ids.compact
  end

  def test_pluck_multiple_columns
    assert_equal [
      [1, "The First Topic"], [2, "The Second Topic of the day"],
      [3, "The Third Topic of the day"], [4, "The Fourth Topic of the day"],
      [5, "The Fifth Topic of the day"]
    ], Topic.order(:id).pluck(:id, :title)
    assert_equal [
      [1, "The First Topic", "David"], [2, "The Second Topic of the day", "Mary"],
      [3, "The Third Topic of the day", "Carl"], [4, "The Fourth Topic of the day", "Carl"],
      [5, "The Fifth Topic of the day", "Jason"]
    ], Topic.order(:id).pluck(:id, :title, :author_name)
  end

  def test_pluck_with_multiple_columns_and_selection_clause
    assert_equal [[1, 50], [2, 50], [3, 50], [4, 60], [5, 55], [6, 53]],
      Account.order(:id).pluck("id, credit_limit")
  end

  def test_pluck_with_multiple_columns_and_includes
    Company.create!(name: "test", contracts: [Contract.new(developer_id: 7)])
    companies_and_developers = Company.order("companies.id").includes(:contracts).pluck(:name, :developer_id)

    assert_equal Company.count, companies_and_developers.length
    assert_equal ["37signals", nil], companies_and_developers.first
    assert_equal ["test", 7], companies_and_developers.last
  end

  def test_pluck_with_reserved_words
    Possession.create!(where: "Over There")

    assert_equal ["Over There"], Possession.pluck(:where)
  end

  def test_pluck_replaces_select_clause
    taks_relation = Topic.select(:approved, :id).order(:id)
    assert_equal [1, 2, 3, 4, 5], taks_relation.pluck(:id)
    assert_equal [false, true, true, true, true], taks_relation.pluck(:approved)
  end

  def test_pluck_columns_with_same_name
    expected = [["The First Topic", "The Second Topic of the day"], ["The Third Topic of the day", "The Fourth Topic of the day"]]
    actual = Topic.joins(:replies).order(:id)
      .pluck("topics.title", "replies_topics.title")
    assert_equal expected, actual
  end

  def test_pluck_functions_with_alias
    assert_equal [
      [1, "The First Topic"], [2, "The Second Topic of the day"],
      [3, "The Third Topic of the day"], [4, "The Fourth Topic of the day"],
      [5, "The Fifth Topic of the day"]
    ], Topic.order(:id).pluck(
      Arel.sql("COALESCE(id, 0) id"),
      Arel.sql("COALESCE(title, 'untitled') title")
    )
  end

  def test_pluck_functions_without_alias
    assert_equal [
      [1, "The First Topic"], [2, "The Second Topic of the day"],
      [3, "The Third Topic of the day"], [4, "The Fourth Topic of the day"],
      [5, "The Fifth Topic of the day"]
    ], Topic.order(:id).pluck(
      Arel.sql("COALESCE(id, 0)"),
      Arel.sql("COALESCE(title, 'untitled')")
    )
  end

  def test_calculation_with_polymorphic_relation
    part = ShipPart.create!(name: "has trinket")
    part.trinkets.create!

    assert_equal part.id, ShipPart.joins(:trinkets).sum(:id)
  end

  def test_pluck_joined_with_polymorphic_relation
    part = ShipPart.create!(name: "has trinket")
    part.trinkets.create!

    assert_equal [part.id], ShipPart.joins(:trinkets).pluck(:id)
  end

  def test_pluck_loaded_relation
    companies = Company.order(:id).limit(3).load

    assert_queries(0) do
      assert_equal ["37signals", "Summit", "Microsoft"], companies.pluck(:name)
    end
  end

  def test_pluck_loaded_relation_multiple_columns
    companies = Company.order(:id).limit(3).load

    assert_queries(0) do
      assert_equal [[1, "37signals"], [2, "Summit"], [3, "Microsoft"]], companies.pluck(:id, :name)
    end
  end

  def test_pluck_loaded_relation_sql_fragment
    companies = Company.order(:name).limit(3).load

    assert_queries(1) do
      assert_equal ["37signals", "Apex", "Ex Nihilo"], companies.pluck(Arel.sql("DISTINCT name"))
    end
  end

  def test_pluck_loaded_relation_aliased_attribute
    companies = Company.order(:id).limit(3).load

    assert_queries(0) do
      assert_equal ["37signals", "Summit", "Microsoft"], companies.pluck(:new_name)
    end
  end

  def test_pick_one
    assert_equal "The First Topic", Topic.order(:id).pick(:heading)
    assert_no_queries do
      assert_nil Topic.none.pick(:heading)
      assert_nil Topic.where(id: 9999999999999999999).pick(:heading)
    end
  end

  def test_pick_two
    assert_equal ["David", "david@loudthinking.com"], Topic.order(:id).pick(:author_name, :author_email_address)
    assert_no_queries do
      assert_nil Topic.none.pick(:author_name, :author_email_address)
      assert_nil Topic.where(id: 9999999999999999999).pick(:author_name, :author_email_address)
    end
  end

  def test_pick_delegate_to_all
    cool_first = minivans(:cool_first)
    assert_equal cool_first.color, Minivan.pick(:color)
  end

  def test_pick_loaded_relation
    companies = Company.order(:id).limit(3).load

    assert_no_queries do
      assert_equal "37signals", companies.pick(:name)
    end
  end

  def test_pick_loaded_relation_multiple_columns
    companies = Company.order(:id).limit(3).load

    assert_no_queries do
      assert_equal [1, "37signals"], companies.pick(:id, :name)
    end
  end

  def test_pick_loaded_relation_sql_fragment
    companies = Company.order(:name).limit(3).load

    assert_queries 1 do
      assert_equal "37signals", companies.pick(Arel.sql("DISTINCT name"))
    end
  end

  def test_pick_loaded_relation_aliased_attribute
    companies = Company.order(:id).limit(3).load

    assert_no_queries do
      assert_equal "37signals", companies.pick(:new_name)
    end
  end

  def test_grouped_calculation_with_polymorphic_relation
    part = ShipPart.create!(name: "has trinket")
    part.trinkets.create!

    assert_equal({ "has trinket" => part.id }, ShipPart.joins(:trinkets).group("ship_parts.name").sum(:id))
  end

  def test_calculation_grouped_by_association_doesnt_error_when_no_records_have_association
    Client.update_all(client_of: nil)
    assert_equal({ nil => Client.count }, Client.group(:firm).count)
  end

  def test_should_reference_correct_aliases_while_joining_tables_of_has_many_through_association
    assert_nothing_raised do
      developer = Developer.create!(name: "developer")
      developer.ratings.includes(comment: :post).where(posts: { id: 1 }).count
    end
  end

  def test_sum_uses_enumerable_version_when_block_is_given
    block_called = false
    relation = Client.all.load

    assert_no_queries do
      assert_equal 0, relation.sum { block_called = true; 0 }
    end
    assert block_called
  end

  def test_having_with_strong_parameters
    params = ProtectedParams.new(credit_limit: "50")

    assert_raises(ActiveModel::ForbiddenAttributesError) do
      Account.group(:id).having(params)
    end

    result = Account.group(:id).having(params.permit!)
    assert_equal 50, result[0].credit_limit
    assert_equal 50, result[1].credit_limit
    assert_equal 50, result[2].credit_limit
  end

  def test_count_takes_attribute_type_precedence_over_database_type
    assert_called(
      Account.connection, :select_all,
      returns: ActiveRecord::Result.new(["count"], [["10"]])
    ) do
      result = Account.count
      assert_equal 10, result
      assert_instance_of Integer, result
    end
  end

  def test_sum_takes_attribute_type_precedence_over_database_type
    assert_called(
      Account.connection, :select_all,
      returns: ActiveRecord::Result.new(["sum"], [[10.to_d]])
    ) do
      result = Account.sum(:credit_limit)
      assert_equal 10, result
      assert_instance_of Integer, result
    end
  end

  def test_group_by_attribute_with_custom_type
    assert_equal({ "proposed" => 2, "published" => 2 }, Book.group(:status).count)
  end

  def test_aggregate_attribute_on_custom_type
    assert_nil Book.sum(:status)
    assert_equal "medium", Book.sum(:difficulty)
    assert_equal "easy", Book.minimum(:difficulty)
    assert_equal "medium", Book.maximum(:difficulty)
    assert_equal({ "proposed" => "proposed", "published" => nil }, Book.group(:status).sum(:status))
    assert_equal({ "proposed" => "easy", "published" => "medium" }, Book.group(:status).sum(:difficulty))
    assert_equal({ "proposed" => "easy", "published" => "easy" }, Book.group(:status).minimum(:difficulty))
    assert_equal({ "proposed" => "easy", "published" => "medium" }, Book.group(:status).maximum(:difficulty))
  end

  def test_minimum_and_maximum_on_non_numeric_type
    assert_equal Date.new(2004, 4, 15), Topic.minimum(:last_read)
    assert_equal Date.new(2004, 4, 15), Topic.maximum(:last_read)
    assert_equal({ false => Date.new(2004, 4, 15), true => nil }, Topic.group(:approved).minimum(:last_read))
    assert_equal({ false => Date.new(2004, 4, 15), true => nil }, Topic.group(:approved).maximum(:last_read))
  end

  def test_minimum_and_maximum_on_time_attributes
    assert_minimum_and_maximum_on_time_attributes(Time)
  end

  def test_minimum_and_maximum_on_tz_aware_attributes
    with_timezone_config aware_attributes: true, zone: "Pacific Time (US & Canada)" do
      Topic.reset_column_information
      assert_minimum_and_maximum_on_time_attributes(ActiveSupport::TimeWithZone)
    end
  ensure
    Topic.reset_column_information
  end

  def assert_minimum_and_maximum_on_time_attributes(time_class)
    actual = Topic.minimum(:written_on)
    assert_equal Time.utc(2003, 7, 16, 14, 28, 11, 223300), actual
    assert_instance_of time_class, actual

    actual = Topic.maximum(:written_on)
    assert_equal Time.utc(2013, 7, 13, 11, 11, 0, 9900), actual
    assert_instance_of time_class, actual

    expected = {
      false => Time.utc(2003, 7, 16, 14, 28, 11, 223300),
      true => Time.utc(2004, 7, 15, 14, 28, 0, 9900),
    }
    actual = Topic.group(:approved).minimum(:written_on)
    assert_equal expected, actual
    assert_instance_of time_class, actual[true]
    assert_instance_of time_class, actual[true]

    expected = {
      false => Time.utc(2003, 7, 16, 14, 28, 11, 223300),
      true => Time.utc(2013, 7, 13, 11, 11, 0, 9900),
    }
    actual = Topic.group(:approved).maximum(:written_on)
    assert_equal expected, actual
    assert_instance_of time_class, actual[true]
    assert_instance_of time_class, actual[true]

    assert_minimum_and_maximum_on_time_attributes_joins_with_column(time_class, :"topics.written_on")
    assert_minimum_and_maximum_on_time_attributes_joins_with_column(time_class, :written_on)
  end
  private :assert_minimum_and_maximum_on_time_attributes

  def assert_minimum_and_maximum_on_time_attributes_joins_with_column(time_class, column)
    actual = Author.joins(:topics).maximum(column)
    assert_equal Time.utc(2004, 7, 15, 14, 28, 0, 9900), actual
    assert_instance_of time_class, actual

    actual = Author.joins(:topics).minimum(column)
    assert_equal Time.utc(2003, 7, 16, 14, 28, 11, 223300), actual
    assert_instance_of time_class, actual

    expected = {
      1 => Time.utc(2003, 7, 16, 14, 28, 11, 223300),
      2 => Time.utc(2004, 7, 15, 14, 28, 0, 9900),
    }

    actual = Author.joins(:topics).group(:id).maximum(column)
    assert_equal expected, actual
    assert_instance_of time_class, actual[1]
    assert_instance_of time_class, actual[2]

    actual = Author.joins(:topics).group(:id).minimum(column)
    assert_equal expected, actual
    assert_instance_of time_class, actual[1]
    assert_instance_of time_class, actual[2]
  end
  private :assert_minimum_and_maximum_on_time_attributes_joins_with_column

  def test_select_avg_with_group_by_as_virtual_attribute_with_sql
    rails_core = companies(:rails_core)

    sql = <<~SQL
      SELECT firm_id, AVG(credit_limit) AS avg_credit_limit
      FROM accounts
      WHERE firm_id = ?
      GROUP BY firm_id
      LIMIT 1
    SQL

    account = Account.find_by_sql([sql, rails_core]).first

    # id was not selected, so it should be nil
    # (cannot select id because it wasn't used in the GROUP BY clause)
    assert_nil account.id

    # firm_id was explicitly selected, so it should be present
    assert_equal(rails_core, account.firm)

    # avg_credit_limit should be present as a virtual attribute
    assert_equal(52.5, account.avg_credit_limit)
  end

  def test_select_avg_with_group_by_as_virtual_attribute_with_ar
    rails_core = companies(:rails_core)

    account = Account
      .select(:firm_id, "AVG(credit_limit) AS avg_credit_limit")
      .where(firm: rails_core)
      .group(:firm_id)
      .take!

    # id was not selected, so it should be nil
    # (cannot select id because it wasn't used in the GROUP BY clause)
    assert_nil account.id

    # firm_id was explicitly selected, so it should be present
    assert_equal(rails_core, account.firm)

    # avg_credit_limit should be present as a virtual attribute
    assert_equal(52.5, account.avg_credit_limit)
  end

  def test_select_avg_with_joins_and_group_by_as_virtual_attribute_with_sql
    rails_core = companies(:rails_core)

    sql = <<~SQL
      SELECT companies.*, AVG(accounts.credit_limit) AS avg_credit_limit
      FROM companies
      INNER JOIN accounts ON companies.id = accounts.firm_id
      WHERE companies.id = ?
      GROUP BY companies.id
      LIMIT 1
    SQL

    firm = DependentFirm.find_by_sql([sql, rails_core]).first

    # all the DependentFirm attributes should be present
    assert_equal rails_core, firm
    assert_equal rails_core.name, firm.name

    # avg_credit_limit should be present as a virtual attribute
    assert_equal(52.5, firm.avg_credit_limit)
  end

  def test_select_avg_with_joins_and_group_by_as_virtual_attribute_with_ar
    rails_core = companies(:rails_core)

    firm = DependentFirm
      .select("companies.*", "AVG(accounts.credit_limit) AS avg_credit_limit")
      .where(id: rails_core)
      .joins(:account)
      .group(:id)
      .take!

    # all the DependentFirm attributes should be present
    assert_equal rails_core, firm
    assert_equal rails_core.name, firm.name

    # avg_credit_limit should be present as a virtual attribute
    assert_equal(52.5, firm.avg_credit_limit)
  end

  def test_count_with_block_and_column_name_raises_an_error
    assert_raises(ArgumentError) do
      Account.count(:firm_id) { true }
    end
  end

  def test_sum_with_block_and_column_name_raises_an_error
    assert_raises(ArgumentError) do
      Account.sum(:firm_id) { 1 }
    end
  end

  test "#skip_query_cache! for #pluck" do
    Account.cache do
      assert_queries(1) do
        Account.pluck(:credit_limit)
        Account.pluck(:credit_limit)
      end

      assert_queries(2) do
        Account.all.skip_query_cache!.pluck(:credit_limit)
        Account.all.skip_query_cache!.pluck(:credit_limit)
      end
    end
  end

  test "#skip_query_cache! for a simple calculation" do
    Account.cache do
      assert_queries(1) do
        Account.calculate(:sum, :credit_limit)
        Account.calculate(:sum, :credit_limit)
      end

      assert_queries(2) do
        Account.all.skip_query_cache!.calculate(:sum, :credit_limit)
        Account.all.skip_query_cache!.calculate(:sum, :credit_limit)
      end
    end
  end

  test "#skip_query_cache! for a grouped calculation" do
    Account.cache do
      assert_queries(1) do
        Account.group(:firm_id).calculate(:sum, :credit_limit)
        Account.group(:firm_id).calculate(:sum, :credit_limit)
      end

      assert_queries(2) do
        Account.all.skip_query_cache!.group(:firm_id).calculate(:sum, :credit_limit)
        Account.all.skip_query_cache!.group(:firm_id).calculate(:sum, :credit_limit)
      end
    end
  end
end
