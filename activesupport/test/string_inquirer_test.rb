require 'abstract_unit'

class StringInquirerTest < ActiveSupport::TestCase
  def test_match
    assert ActiveSupport::StringInquirer.new("production").production?
  end

  def test_miss
    assert !ActiveSupport::StringInquirer.new("production").development?
  end

  def test_missing_question_mark
    assert_raise(NoMethodError) { ActiveSupport::StringInquirer.new("production").production }
  end

  def test_dump_for_serialize
    inquirer = ActiveSupport::StringInquirer.new("Gun Metal")
    dumped = ActiveSupport::StringInquirer.dump(inquirer)
    assert_instance_of String, dumped
    assert_equal "gun_metal", dumped
  end

  def test_nil_dump_for_serialize
    assert_nil ActiveSupport::StringInquirer.dump(nil)
    assert_nil ActiveSupport::StringInquirer.dump("")
  end

  def test_load_for_serialize
    loaded = ActiveSupport::StringInquirer.load("gun_metal")
    assert_instance_of ActiveSupport::StringInquirer, loaded
    assert loaded.gun_metal?
  end

  def test_nil_load_for_serialize
    assert_nil ActiveSupport::StringInquirer.load(nil)
    assert_nil ActiveSupport::StringInquirer.load("")
  end
end
