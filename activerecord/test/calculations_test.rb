require 'abstract_unit'
require 'fixtures/company'
require 'fixtures/topic'

Company.has_many :accounts

class CalculationsTest < Test::Unit::TestCase
  fixtures :companies, :accounts, :topics

  def test_should_sum_field
    assert_equal 318, Account.sum(:credit_limit)
  end

  def test_should_average_field
    value = Account.average(:credit_limit)
    assert_kind_of Float, value
    assert_in_delta 53.0, value, 0.001
  end

  def test_should_get_maximum_of_field
    assert_equal 60, Account.maximum(:credit_limit)
  end

  def test_should_get_maximum_of_field_with_include
    assert_equal 50, Account.maximum(:credit_limit, :include => :firm, :conditions => "companies.name != 'Summit'")
  end

  def test_should_get_maximum_of_field_with_scoped_include
    Account.with_scope :find => { :include => :firm, :conditions => "companies.name != 'Summit'" } do
      assert_equal 50, Account.maximum(:credit_limit)
    end
  end

  def test_should_get_minimum_of_field
    assert_equal 50, Account.minimum(:credit_limit)
  end

  def test_should_group_by_field
    c = Account.sum(:credit_limit, :group => :firm_id)
    [1,6,2].each { |firm_id| assert c.keys.include?(firm_id) }
  end

  def test_should_group_by_summed_field
    c = Account.sum(:credit_limit, :group => :firm_id)
    assert_equal 50,   c[1]
    assert_equal 105,  c[6]
    assert_equal 60,   c[2]
  end

  def test_should_order_by_grouped_field
    c = Account.sum(:credit_limit, :group => :firm_id, :order => "firm_id")
    assert_equal [1, 2, 6, 9], c.keys.compact
  end

  def test_should_order_by_calculation
    c = Account.sum(:credit_limit, :group => :firm_id, :order => "sum_credit_limit desc, firm_id")
    assert_equal [105, 60, 53, 50, 50], c.keys.collect { |k| c[k] }
    assert_equal [6, 2, 9, 1], c.keys.compact
  end

  def test_should_limit_calculation
    c = Account.sum(:credit_limit, :conditions => "firm_id IS NOT NULL",
                    :group => :firm_id, :order => "firm_id", :limit => 2)
    assert_equal [1, 2], c.keys.compact
  end

  def test_should_limit_calculation_with_offset
    c = Account.sum(:credit_limit, :conditions => "firm_id IS NOT NULL",
                    :group => :firm_id, :order => "firm_id", :limit => 2, :offset => 1)
    assert_equal [2, 6], c.keys.compact
  end

  def test_should_group_by_summed_field_having_condition
    c = Account.sum(:credit_limit, :group => :firm_id, 
                                   :having => 'sum(credit_limit) > 50')
    assert_nil        c[1]
    assert_equal 105, c[6]
    assert_equal 60,  c[2]
  end

  def test_should_group_by_summed_association
    c = Account.sum(:credit_limit, :group => :firm)
    assert_equal 50,   c[companies(:first_firm)]
    assert_equal 105,  c[companies(:rails_core)]
    assert_equal 60,   c[companies(:first_client)]
  end
  
  def test_should_sum_field_with_conditions
    assert_equal 105, Account.sum(:credit_limit, :conditions => 'firm_id = 6')
  end

  def test_should_group_by_summed_field_with_conditions
    c = Account.sum(:credit_limit, :conditions => 'firm_id > 1', 
                                   :group => :firm_id)
    assert_nil        c[1]
    assert_equal 105, c[6]
    assert_equal 60,  c[2]
  end
  
  def test_should_group_by_summed_field_with_conditions_and_having
    c = Account.sum(:credit_limit, :conditions => 'firm_id > 1', 
                                   :group => :firm_id, 
                                   :having => 'sum(credit_limit) > 60')
    assert_nil        c[1]
    assert_equal 105, c[6]
    assert_nil        c[2]
  end

  def test_should_group_by_fields_with_table_alias
    c = Account.sum(:credit_limit, :group => 'accounts.firm_id')
    assert_equal 50,  c[1]
    assert_equal 105, c[6]
    assert_equal 60,  c[2]
  end
  
  def test_should_calculate_with_invalid_field
    assert_equal 6, Account.calculate(:count, '*')
    assert_equal 6, Account.calculate(:count, :all)
  end
  
  def test_should_calculate_grouped_with_invalid_field
    c = Account.count(:all, :group => 'accounts.firm_id')
    assert_equal 1, c[1]
    assert_equal 2, c[6]
    assert_equal 1, c[2]
  end
  
  def test_should_calculate_grouped_association_with_invalid_field
    c = Account.count(:all, :group => :firm)
    assert_equal 1, c[companies(:first_firm)]
    assert_equal 2, c[companies(:rails_core)]
    assert_equal 1, c[companies(:first_client)]
  end
  
  def test_should_not_modify_options_when_using_includes
    options = {:conditions => 'companies.id > 1', :include => :firm}
    options_copy = options.dup
    
    Account.count(:all, options)
    assert_equal options_copy, options
  end

  def test_should_calculate_grouped_by_function
    c = Company.count(:all, :group => "UPPER(#{QUOTED_TYPE})")
    assert_equal 2, c[nil]
    assert_equal 1, c['DEPENDENTFIRM']
    assert_equal 3, c['CLIENT']
    assert_equal 2, c['FIRM']
  end
  
  def test_should_calculate_grouped_by_function_with_table_alias
    c = Company.count(:all, :group => "UPPER(companies.#{QUOTED_TYPE})")
    assert_equal 2, c[nil]
    assert_equal 1, c['DEPENDENTFIRM']
    assert_equal 3, c['CLIENT']
    assert_equal 2, c['FIRM']
  end
  
  def test_should_not_overshadow_enumerable_sum
    assert_equal 6, [1, 2, 3].sum(&:abs)
  end

  def test_should_sum_scoped_field
    assert_equal 15, companies(:rails_core).companies.sum(:id)
  end

  def test_should_sum_scoped_field_with_conditions
    assert_equal 8,  companies(:rails_core).companies.sum(:id, :conditions => 'id > 7')
  end

  def test_should_group_by_scoped_field
    c = companies(:rails_core).companies.sum(:id, :group => :name)
    assert_equal 7, c['Leetsoft']
    assert_equal 8, c['Jadedpixel']
  end

  def test_should_group_by_summed_field_with_conditions_and_having
    c = companies(:rails_core).companies.sum(:id, :group => :name,
                                                  :having => 'sum(id) > 7')
    assert_nil      c['Leetsoft']
    assert_equal 8, c['Jadedpixel']
  end

  def test_should_reject_invalid_options
    assert_nothing_raised do
      [:count, :sum].each do |func|
        # empty options are valid
        Company.send(:validate_calculation_options, func)
        # these options are valid for all calculations
        [:select, :conditions, :joins, :order, :group, :having, :distinct].each do |opt| 
          Company.send(:validate_calculation_options, func, opt => true)
        end
      end
      
      # :include is only valid on :count
      Company.send(:validate_calculation_options, :count, :include => true)
    end
    
    assert_raises(ArgumentError) { Company.send(:validate_calculation_options, :sum,   :foo => :bar) }
    assert_raises(ArgumentError) { Company.send(:validate_calculation_options, :count, :foo => :bar) }
  end

  def test_should_count_selected_field_with_include
    assert_equal 6, Account.count(:distinct => true, :include => :firm)
    assert_equal 4, Account.count(:distinct => true, :include => :firm, :select => :credit_limit)
  end

  def test_deprecated_count_with_string_parameters
    assert_deprecated('count') { Account.count('credit_limit > 50') }
  end

  def test_count_with_no_parameters_isnt_deprecated
    assert_not_deprecated { Account.count }
  end

  def test_count_with_too_many_parameters_raises
    assert_raise(ArgumentError) { Account.count(1, 2, 3) }
  end
end
