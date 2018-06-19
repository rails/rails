# frozen_string_literal: true

require "cases/helper"
require "models/book"
require "models/club"
require "models/company"
require "models/contract"
require "models/edge"
require "models/organization"
require "models/possession"
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

class CalculationsTest < ActiveRecord::TestCase
  fixtures :companies, :accounts, :topics, :speedometers, :minivans, :books, :posts, :comments

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

  def test_should_get_maximum_of_datetime_with_time_zone_conversion
    with_timezone_config default: :utc, aware_attributes: true, zone: "Eastern Time (US & Canada)" do
      Comment.reset_column_information

      assert_equal ActiveSupport::TimeWithZone, Comment.maximum(:updated_at).class
    end
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
    c = Account.group(:firm_id).sum(:credit_limit)
    assert_equal 50,   c[1]
    assert_equal 105,  c[6]
    assert_equal 60,   c[2]
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
    accounts = Account.limit(4)

    assert_equal 3, accounts.count(:firm_id)
    assert_equal 3, accounts.select(:firm_id).count
  end

  def test_limit_should_apply_before_count_arel_attribute
    accounts = Account.limit(4)

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

    queries = assert_sql { Account.limit(1).count }
    assert_equal 1, queries.length
    assert_match(/LIMIT/, queries.first)
  end

  def test_offset_is_kept
    return if current_adapter?(:OracleAdapter)

    queries = assert_sql { Account.offset(1).count }
    assert_equal 1, queries.length
    assert_match(/OFFSET/, queries.first)
  end

  def test_limit_with_offset_is_kept
    return if current_adapter?(:OracleAdapter)

    queries = assert_sql { Account.limit(1).offset(1).count }
    assert_equal 1, queries.length
    assert_match(/LIMIT/, queries.first)
    assert_match(/OFFSET/, queries.first)
  end

  def test_no_limit_no_offset
    queries = assert_sql { Account.count }
    assert_equal 1, queries.length
    assert_no_match(/LIMIT/, queries.first)
    assert_no_match(/OFFSET/, queries.first)
  end

  def test_count_on_invalid_columns_raises
    e = assert_raises(ActiveRecord::StatementInvalid) {
      Account.select("credit_limit, firm_name").count
    }

    assert_match %r{accounts}i, e.message
    assert_match "credit_limit, firm_name", e.message
  end

  def test_apply_distinct_in_count
    queries = assert_sql do
      Account.distinct.count
      Account.group(:firm_id).distinct.count
    end

    queries.each do |query|
      # `table_alias_length` in `column_alias_for` would execute
      # "SHOW max_identifier_length" statement in PostgreSQL adapter.
      next if query == "SHOW max_identifier_length"
      assert_match %r{\ASELECT(?! DISTINCT) COUNT\(DISTINCT\b}, query
    end
  end

  def test_count_with_eager_loading_and_custom_order
    posts = Post.includes(:comments).order("comments.id")
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
  end

  def test_should_not_perform_joined_include_by_default
    assert_equal Account.count, Account.includes(:firm).count
    queries = assert_sql { Account.includes(:firm).count }
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
    assert_equal({ 1 => 1 }, Firm.joins(:accounts).group(:firm_id).count)
    assert_equal({ 1 => 1 }, Firm.joins(:accounts).group("accounts.firm_id").count)
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
    if current_adapter?(:SQLite3Adapter, :Mysql2Adapter, :PostgreSQLAdapter, :OracleAdapter)
      assert_equal 636, Account.sum("2 * credit_limit")
    else
      assert_equal 636, Account.sum("2 * credit_limit").to_i
    end
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

  if current_adapter?(:Mysql2Adapter)
    def test_from_option_with_specified_index
      assert_equal Edge.count(:all), Edge.from("edges USE INDEX(unique_edge_index)").count(:all)
      assert_equal Edge.where("sink_id < 5").count(:all),
          Edge.from("edges USE INDEX(unique_edge_index)").where("sink_id < 5").count(:all)
    end
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
    Company.create!(name: "test", contracts: [Contract.new(developer_id: 7)])
    assert_equal [7], Company.joins(:contracts).pluck(:developer_id)
  end

  def test_pluck_with_selection_clause
    assert_equal [50, 53, 55, 60], Account.pluck(Arel.sql("DISTINCT credit_limit")).sort
    assert_equal [50, 53, 55, 60], Account.pluck(Arel.sql("DISTINCT accounts.credit_limit")).sort
    assert_equal [50, 53, 55, 60], Account.pluck(Arel.sql("DISTINCT(credit_limit)")).sort

    # MySQL returns "SUM(DISTINCT(credit_limit))" as the column name unless
    # an alias is provided.  Without the alias, the column cannot be found
    # and properly typecast.
    assert_equal [50 + 53 + 55 + 60], Account.pluck(Arel.sql("SUM(DISTINCT(credit_limit)) as credit_limit"))
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

  def test_group_by_with_limit
    expected = { "Post" => 8, "SpecialPost" => 1 }
    actual = Post.includes(:comments).group(:type).order(:type).limit(2).count("comments.id")
    assert_equal expected, actual
  end

  def test_group_by_with_offset
    expected = { "SpecialPost" => 1, "StiPost" => 2 }
    actual = Post.includes(:comments).group(:type).order(:type).offset(1).count("comments.id")
    assert_equal expected, actual
  end

  def test_group_by_with_limit_and_offset
    expected = { "SpecialPost" => 1 }
    actual = Post.includes(:comments).group(:type).order(:type).offset(1).limit(1).count("comments.id")
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
      Account.pluck("id, credit_limit")
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
    actual = Topic.joins(:replies)
      .pluck("topics.title", "replies_topics.title")
    assert_equal expected, actual
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
    Company.attribute_names # Load schema information so we don't query below
    companies = Company.order(:id).limit(3).load

    assert_no_queries do
      assert_equal ["37signals", "Summit", "Microsoft"], companies.pluck(:name)
    end
  end

  def test_pluck_loaded_relation_multiple_columns
    Company.attribute_names # Load schema information so we don't query below
    companies = Company.order(:id).limit(3).load

    assert_no_queries do
      assert_equal [[1, "37signals"], [2, "Summit"], [3, "Microsoft"]], companies.pluck(:id, :name)
    end
  end

  def test_pluck_loaded_relation_sql_fragment
    Company.attribute_names # Load schema information so we don't query below
    companies = Company.order(:name).limit(3).load

    assert_queries 1 do
      assert_equal ["37signals", "Apex", "Ex Nihilo"], companies.pluck(Arel.sql("DISTINCT name"))
    end
  end

  def test_pick_one
    assert_equal "The First Topic", Topic.order(:id).pick(:heading)
    assert_nil Topic.none.pick(:heading)
    assert_nil Topic.where("1=0").pick(:heading)
  end

  def test_pick_two
    assert_equal ["David", "david@loudthinking.com"], Topic.order(:id).pick(:author_name, :author_email_address)
    assert_nil Topic.none.pick(:author_name, :author_email_address)
    assert_nil Topic.where("1=0").pick(:author_name, :author_email_address)
  end

  def test_pick_delegate_to_all
    cool_first = minivans(:cool_first)
    assert_equal cool_first.color, Minivan.pick(:color)
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
    protected_params = Class.new do
      attr_reader :permitted
      alias :permitted? :permitted

      def initialize(parameters)
        @parameters = parameters
        @permitted = false
      end

      def to_h
        @parameters
      end

      def permit!
        @permitted = true
        self
      end
    end

    params = protected_params.new(credit_limit: "50")

    assert_raises(ActiveModel::ForbiddenAttributesError) do
      Account.group(:id).having(params)
    end

    result = Account.group(:id).having(params.permit!)
    assert_equal 50, result[0].credit_limit
    assert_equal 50, result[1].credit_limit
    assert_equal 50, result[2].credit_limit
  end

  def test_group_by_attribute_with_custom_type
    assert_equal({ "proposed" => 2, "published" => 2 }, Book.group(:status).count)
  end

  def test_deprecate_count_with_block_and_column_name
    assert_deprecated do
      assert_equal 6, Account.count(:firm_id) { true }
    end
  end

  def test_deprecate_sum_with_block_and_column_name
    assert_deprecated do
      assert_equal 6, Account.sum(:firm_id) { 1 }
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
