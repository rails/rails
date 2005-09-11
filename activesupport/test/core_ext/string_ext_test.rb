require 'test/unit'
require 'date'
require File.dirname(__FILE__) + '/../../lib/active_support/core_ext/string'
require File.dirname(__FILE__) + '/../../lib/active_support/core_ext/kernel'

silence_warnings do
  require File.dirname(__FILE__) + '/../inflector_test'
end

class StringInflectionsTest < Test::Unit::TestCase
  def test_pluralize
    InflectorTest::SingularToPlural.each do |singular, plural|
      assert_equal(plural, singular.pluralize)
    end

    assert_equal("plurals", "plurals".pluralize)
  end

  def test_singularize
    InflectorTest::SingularToPlural.each do |singular, plural|
      assert_equal(singular, plural.singularize)
    end
  end

  def test_camelize
    InflectorTest::CamelToUnderscore.each do |camel, underscore|
      assert_equal(camel, underscore.camelize)
    end
  end

  def test_underscore
    InflectorTest::CamelToUnderscore.each do |camel, underscore|
      assert_equal(underscore, camel.underscore)
    end
    
    assert_equal "html_tidy", "HTMLTidy".underscore
    assert_equal "html_tidy_generator", "HTMLTidyGenerator".underscore
  end

  def test_demodulize
    assert_equal "Account", Inflector.demodulize("MyApplication::Billing::Account")
  end

  def test_foreign_key
    InflectorTest::ClassNameToForeignKeyWithUnderscore.each do |klass, foreign_key|
      assert_equal(foreign_key, klass.foreign_key)
    end

    InflectorTest::ClassNameToForeignKeyWithoutUnderscore.each do |klass, foreign_key|
      assert_equal(foreign_key, klass.foreign_key(false))
    end
  end

  def test_tableize
    InflectorTest::ClassNameToTableName.each do |class_name, table_name|
      assert_equal(table_name, class_name.tableize)
    end
  end

  def test_classify
    InflectorTest::ClassNameToTableName.each do |class_name, table_name|
      assert_equal(class_name, table_name.classify)
    end
  end
  
  def test_string_to_time
    assert_equal Time.utc(2005, 2, 27, 23, 50), "2005-02-27 23:50".to_time
    assert_equal Time.local(2005, 2, 27, 23, 50), "2005-02-27 23:50".to_time(:local)
    assert_equal Date.new(2005, 2, 27), "2005-02-27".to_date
  end
  
  def test_access
    s = "hello"
    assert_equal "h", s.at(0)
    
    assert_equal "llo", s.from(2)
    assert_equal "hel", s.to(2)
    
    assert_equal "h", s.first
    assert_equal "he", s.first(2)

    assert_equal "o", s.last
    assert_equal "llo", s.last(3)
  end

  def test_starts_ends_with
    s = "hello"    
    assert s.starts_with?('h')    
    assert s.starts_with?('hel')    
    assert !s.starts_with?('el')    

    assert s.ends_with?('o')    
    assert s.ends_with?('lo')    
    assert !s.ends_with?('el')  
  end
end
