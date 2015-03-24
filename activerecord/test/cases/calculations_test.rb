require "cases/helper"
require 'models/club'
require 'models/company'
require "models/contract"
require 'models/edge'
require 'models/organization'
require 'models/possession'
require 'models/topic'
require 'models/reply'
require 'models/minivan'
require 'models/speedometer'
require 'models/ship_part'
require 'models/developer'
require 'models/comment'
require 'models/rating'
require 'models/post'

Company.has_many :accounts

class NumericData < ActiveRecord::Base
  self.table_name = 'numeric_data'
end

class CalculationsTest < ActiveRecord::TestCase
  fixtures :companies, :accounts, :topics

  def test_should_sum_field
    assert_equal 318, Account.sum(:credit_limit)
  end

  def test_should_average_field
    value = Account.average(:credit_limit)
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
    ShipPart.create!(:id => 3, :name => 'foo')
    value = ShipPart.average(:id)
    assert_equal 3, value
  end

  def test_should_return_nil_as_average
    assert_nil NumericData.average(:bank_balance)
  end

  def test_type_cast_calculated_value_should_convert_db_averages_of_fixnum_class_to_decimal
    assert_equal 0, NumericData.all.send(:type_cast_calculated_value, 0, nil, 'avg')
    assert_equal 53.0, NumericData.all.send(:type_cast_calculated_value, 53, nil, 'avg')
  end

  def test_should_get_maximum_of_field
    assert_equal 60, Account.maximum(:credit_limit)
  end

  def test_should_get_maximum_of_field_with_include
    assert_equal 55, Account.where("companies.name != 'Summit'").references(:companies).includes(:firm).maximum(:credit_limit)
  end

  def test_should_get_minimum_of_field
    assert_equal 50, Account.minimum(:credit_limit)
  end

  def test_should_group_by_field
    c = Account.group(:firm_id).sum(:credit_limit)
    [1,6,2].each do |firm_id|
      assert c.keys.include?(firm_id), "Group #{c.inspect} does not contain firm_id #{firm_id}"
    end
  end

  def test_should_group_by_arel_attribute
    c = Account.group(Account.arel_table[:firm_id]).sum(:credit_limit)
    [1,6,2].each do |firm_id|
      assert c.keys.include?(firm_id), "Group #{c.inspect} does not contain firm_id #{firm_id}"
    end
  end

  def test_should_group_by_multiple_fields
    c = Account.group('firm_id', :credit_limit).count(:all)
    [ [nil, 50], [1, 50], [6, 50], [6, 55], [9, 53], [2, 60] ].each { |firm_and_limit| assert c.keys.include?(firm_and_limit) }
  end

  def test_should_group_by_multiple_fields_having_functions
    c = Topic.group(:author_name, 'COALESCE(type, title)').count(:all)
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
    accounts = Account.limit(3).where('firm_id IS NOT NULL')

    assert_equal 3, accounts.count(:firm_id)
    assert_equal 3, accounts.select(:firm_id).count
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

  def test_should_group_by_summed_field_having_condition
    c = Account.group(:firm_id).having('sum(credit_limit) > 50').sum(:credit_limit)
    assert_nil        c[1]
    assert_equal 105, c[6]
    assert_equal 60,  c[2]
  end

  def test_should_group_by_summed_field_having_condition_from_select
    c = Account.select("MIN(credit_limit) AS min_credit_limit").group(:firm_id).having("MIN(credit_limit) > 50").sum(:credit_limit)
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
    assert_equal 105, Account.where('firm_id = 6').sum(:credit_limit)
  end

  def test_should_return_zero_if_sum_conditions_return_nothing
    assert_equal 0, Account.where('1 = 2').sum(:credit_limit)
    assert_equal 0, companies(:rails_core).companies.where('1 = 2').sum(:id)
  end

  def test_sum_should_return_valid_values_for_decimals
    NumericData.create(:bank_balance => 19.83)
    assert_equal 19.83, NumericData.sum(:bank_balance)
  end

  def test_should_return_type_casted_values_with_group_and_expression
    assert_equal 0.5, Account.group(:firm_name).sum('0.01 * credit_limit')['37signals']
  end

  def test_should_group_by_summed_field_with_conditions
    c = Account.where('firm_id > 1').group(:firm_id).sum(:credit_limit)
    assert_nil        c[1]
    assert_equal 105, c[6]
    assert_equal 60,  c[2]
  end

  def test_should_group_by_summed_field_with_conditions_and_having
    c = Account.where('firm_id > 1').group(:firm_id).
     having('sum(credit_limit) > 60').sum(:credit_limit)
    assert_nil        c[1]
    assert_equal 105, c[6]
    assert_nil        c[2]
  end

  def test_should_group_by_fields_with_table_alias
    c = Account.group('accounts.firm_id').sum(:credit_limit)
    assert_equal 50,  c[1]
    assert_equal 105, c[6]
    assert_equal 60,  c[2]
  end

  def test_should_calculate_with_invalid_field
    assert_equal 6, Account.calculate(:count, '*')
    assert_equal 6, Account.calculate(:count, :all)
  end

  def test_should_calculate_grouped_with_invalid_field
    c = Account.group('accounts.firm_id').count(:all)
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
    Speedometer.create! id: 'ABC'
    Minivan.create! id: 'OMG', speedometer_id: 'ABC'

    c = Minivan.group(:speedometer).count(:all)
    first_key = c.keys.first
    assert_equal Speedometer, first_key.class
    assert_equal 1, c[first_key]
  end

  def test_should_calculate_grouped_association_with_foreign_key_option
    Account.belongs_to :another_firm, :class_name => 'Firm', :foreign_key => 'firm_id'
    c = Account.group(:another_firm).count(:all)
    assert_equal 1, c[companies(:first_firm)]
    assert_equal 2, c[companies(:rails_core)]
    assert_equal 1, c[companies(:first_client)]
  end

  def test_should_calculate_grouped_by_function
    c = Company.group("UPPER(#{QUOTED_TYPE})").count(:all)
    assert_equal 2, c[nil]
    assert_equal 1, c['DEPENDENTFIRM']
    assert_equal 5, c['CLIENT']
    assert_equal 2, c['FIRM']
  end

  def test_should_calculate_grouped_by_function_with_table_alias
    c = Company.group("UPPER(companies.#{QUOTED_TYPE})").count(:all)
    assert_equal 2, c[nil]
    assert_equal 1, c['DEPENDENTFIRM']
    assert_equal 5, c['CLIENT']
    assert_equal 2, c['FIRM']
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
    assert_equal 8,  companies(:rails_core).companies.where('id > 7').sum(:id)
  end

  def test_should_group_by_scoped_field
    c = companies(:rails_core).companies.group(:name).sum(:id)
    assert_equal 7, c['Leetsoft']
    assert_equal 8, c['Jadedpixel']
  end

  def test_should_group_by_summed_field_through_association_and_having
    c = companies(:rails_core).companies.group(:name).having('sum(id) > 7').sum(:id)
    assert_nil      c['Leetsoft']
    assert_equal 8, c['Jadedpixel']
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
    joined_count = Account.includes(:firm).where(:companies => {:name => '37signals'}).count
    assert_equal 1, joined_count
  end

  def test_should_count_scoped_select
    Account.update_all("credit_limit = NULL")
    assert_equal 0, Account.select("credit_limit").count
  end

  def test_should_count_scoped_select_with_options
    Account.update_all("credit_limit = NULL")
    Account.last.update_columns('credit_limit' => 49)
    Account.first.update_columns('credit_limit' => 51)

    assert_equal 1, Account.select("credit_limit").where('credit_limit >= 50').count
  end

  def test_should_count_manual_select_with_include
    assert_equal 6, Account.select("DISTINCT accounts.id").includes(:firm).count
  end

  def test_count_with_column_parameter
    assert_equal 5, Account.count(:firm_id)
  end

  def test_count_with_distinct
    assert_equal 4, Account.select(:credit_limit).distinct.count
    assert_equal 4, Account.select(:credit_limit).uniq.count
  end

  def test_count_with_aliased_attribute
    assert_equal 6, Account.count(:available_credit)
  end

  def test_count_with_column_and_options_parameter
    assert_equal 2, Account.where("credit_limit = 50 AND firm_id IS NOT NULL").count(:firm_id)
  end

  def test_should_count_field_in_joined_table
    assert_equal 5, Account.joins(:firm).count('companies.id')
    assert_equal 4, Account.joins(:firm).distinct.count('companies.id')
  end

  def test_should_count_field_in_joined_table_with_group_by
    c = Account.group('accounts.firm_id').joins(:firm).count('companies.id')

    [1,6,2,9].each { |firm_id| assert c.keys.include?(firm_id) }
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
    assert_equal 1, Account.where(firm_name: '37signals').count
    assert_equal 1, Account.where(firm_name: '37signals').order(:firm_name).count
    assert_equal 1, Account.where(firm_name: '37signals').order(:firm_name).reverse_order.count
  end

  def test_should_sum_expression
    # Oracle adapter returns floating point value 636.0 after SUM
    if current_adapter?(:OracleAdapter)
      assert_equal 636, Account.sum("2 * credit_limit")
    else
      assert_equal 636, Account.sum("2 * credit_limit").to_i
    end
  end

  def test_sum_expression_returns_zero_when_no_records_to_sum
    assert_equal 0, Account.where('1 = 2').sum("2 * credit_limit")
  end

  def test_count_with_from_option
    assert_equal Company.count(:all), Company.from('companies').count(:all)
    assert_equal Account.where("credit_limit = 50").count(:all),
        Account.from('accounts').where("credit_limit = 50").count(:all)
    assert_equal Company.where(:type => "Firm").count(:type),
        Company.where(:type => "Firm").from('companies').count(:type)
  end

  def test_sum_with_from_option
    assert_equal Account.sum(:credit_limit), Account.from('accounts').sum(:credit_limit)
    assert_equal Account.where("credit_limit > 50").sum(:credit_limit),
        Account.where("credit_limit > 50").from('accounts').sum(:credit_limit)
  end

  def test_average_with_from_option
    assert_equal Account.average(:credit_limit), Account.from('accounts').average(:credit_limit)
    assert_equal Account.where("credit_limit > 50").average(:credit_limit),
        Account.where("credit_limit > 50").from('accounts').average(:credit_limit)
  end

  def test_minimum_with_from_option
    assert_equal Account.minimum(:credit_limit), Account.from('accounts').minimum(:credit_limit)
    assert_equal Account.where("credit_limit > 50").minimum(:credit_limit),
        Account.where("credit_limit > 50").from('accounts').minimum(:credit_limit)
  end

  def test_maximum_with_from_option
    assert_equal Account.maximum(:credit_limit), Account.from('accounts').maximum(:credit_limit)
    assert_equal Account.where("credit_limit > 50").maximum(:credit_limit),
        Account.where("credit_limit > 50").from('accounts').maximum(:credit_limit)
  end

  def test_maximum_with_not_auto_table_name_prefix_if_column_included
    Company.create!(:name => "test", :contracts => [Contract.new(:developer_id => 7)])

    assert_equal 7, Company.includes(:contracts).maximum(:developer_id)
  end

  def test_minimum_with_not_auto_table_name_prefix_if_column_included
    Company.create!(:name => "test", :contracts => [Contract.new(:developer_id => 7)])

    assert_equal 7, Company.includes(:contracts).minimum(:developer_id)
  end

  def test_sum_with_not_auto_table_name_prefix_if_column_included
    Company.create!(:name => "test", :contracts => [Contract.new(:developer_id => 7)])

    assert_equal 7, Company.includes(:contracts).sum(:developer_id)
  end


  def test_from_option_with_specified_index
    if Edge.connection.adapter_name == 'MySQL' or Edge.connection.adapter_name == 'Mysql2'
      assert_equal Edge.count(:all), Edge.from('edges USE INDEX(unique_edge_index)').count(:all)
      assert_equal Edge.where('sink_id < 5').count(:all),
          Edge.from('edges USE INDEX(unique_edge_index)').where('sink_id < 5').count(:all)
    end
  end

  def test_from_option_with_table_different_than_class
    assert_equal Account.count(:all), Company.from('accounts').count(:all)
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
    assert_equal [1,2,3,4,5], Topic.order(:id).pluck(:id)
  end

  def test_pluck_without_column_names
    assert_equal [[1, "Firm", 1, nil, "37signals", nil, 1, nil, ""]],
      Company.order(:id).limit(1).pluck
  end

  def test_pluck_type_cast
    topic = topics(:first)
    relation = Topic.where(:id => topic.id)
    assert_equal [ topic.approved ], relation.pluck(:approved)
    assert_equal [ topic.last_read ], relation.pluck(:last_read)
    assert_equal [ topic.written_on ], relation.pluck(:written_on)
  end

  def test_pluck_and_uniq
    assert_equal [50, 53, 55, 60], Account.order(:credit_limit).uniq.pluck(:credit_limit)
  end

  def test_pluck_in_relation
    company = Company.first
    contract = company.contracts.create!
    assert_equal [contract.id], company.contracts.pluck(:id)
  end

  def test_pluck_on_aliased_attribute
    assert_equal 'The First Topic', Topic.order(:id).pluck(:heading).first
  end

  def test_pluck_with_serialization
    t = Topic.create!(:content => { :foo => :bar })
    assert_equal [{:foo => :bar}], Topic.where(:id => t.id).pluck(:content)
  end

  def test_pluck_with_qualified_column_name
    assert_equal [1,2,3,4,5], Topic.order(:id).pluck("topics.id")
  end

  def test_pluck_auto_table_name_prefix
    c = Company.create!(:name => "test", :contracts => [Contract.new])
    assert_equal [c.id], Company.joins(:contracts).pluck(:id)
  end

  def test_pluck_if_table_included
    c = Company.create!(:name => "test", :contracts => [Contract.new(:developer_id => 7)])
    assert_equal [c.id], Company.includes(:contracts).where("contracts.id" => c.contracts.first).pluck(:id)
  end

  def test_pluck_not_auto_table_name_prefix_if_column_joined
    Company.create!(:name => "test", :contracts => [Contract.new(:developer_id => 7)])
    assert_equal [7], Company.joins(:contracts).pluck(:developer_id)
  end

  def test_pluck_with_selection_clause
    assert_equal [50, 53, 55, 60], Account.pluck('DISTINCT credit_limit').sort
    assert_equal [50, 53, 55, 60], Account.pluck('DISTINCT accounts.credit_limit').sort
    assert_equal [50, 53, 55, 60], Account.pluck('DISTINCT(credit_limit)').sort

    # MySQL returns "SUM(DISTINCT(credit_limit))" as the column name unless
    # an alias is provided.  Without the alias, the column cannot be found
    # and properly typecast.
    assert_equal [50 + 53 + 55 + 60], Account.pluck('SUM(DISTINCT(credit_limit)) as credit_limit')
  end

  def test_plucks_with_ids
    assert_equal Company.all.map(&:id).sort, Company.ids.sort
  end

  def test_pluck_with_includes_limit_and_empty_result
    assert_equal [], Topic.includes(:replies).limit(0).pluck(:id)
    assert_equal [], Topic.includes(:replies).limit(1).where('0 = 1').pluck(:id)
  end

  def test_pluck_not_auto_table_name_prefix_if_column_included
    Company.create!(:name => "test", :contracts => [Contract.new(:developer_id => 7)])
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
      Account.pluck('id, credit_limit')
  end

  def test_pluck_with_multiple_columns_and_includes
    Company.create!(:name => "test", :contracts => [Contract.new(:developer_id => 7)])
    companies_and_developers = Company.order('companies.id').includes(:contracts).pluck(:name, :developer_id)

    assert_equal Company.count, companies_and_developers.length
    assert_equal ["37signals", nil], companies_and_developers.first
    assert_equal ["test", 7], companies_and_developers.last
  end

  def test_pluck_with_reserved_words
    Possession.create!(:where => "Over There")

    assert_equal ["Over There"], Possession.pluck(:where)
  end

  def test_pluck_replaces_select_clause
    taks_relation = Topic.select(:approved, :id).order(:id)
    assert_equal [1,2,3,4,5], taks_relation.pluck(:id)
    assert_equal [false, true, true, true, true], taks_relation.pluck(:approved)
  end

  def test_pluck_columns_with_same_name
    expected = [["The First Topic", "The Second Topic of the day"], ["The Third Topic of the day", "The Fourth Topic of the day"]]
    actual = Topic.joins(:replies)
      .pluck('topics.title', 'replies_topics.title')
    assert_equal expected, actual
  end

  def test_should_reference_correct_aliases_while_joining_tables_of_has_many_through_association
    assert_nothing_raised ActiveRecord::StatementInvalid do
      developer = Developer.create!(name: 'developer')
      developer.ratings.includes(comment: :post).where(posts: { id: 1 }).count
    end
  end
end
