require "#{File.dirname(__FILE__)}/abstract_unit"
require "fixtures/person"

class BaseErrorsTest < Test::Unit::TestCase
  def setup
    ActiveResource::HttpMock.respond_to do |mock|
      mock.post "/people.xml", {}, "<?xml version=\"1.0\" encoding=\"UTF-8\"?><errors><error>Age can't be blank</error><error>Name can't be blank</error><error>Name must start with a letter</error><error>Person quota full for today.</error></errors>", 422
    end
    @person = Person.new(:name => '', :age => '')
    assert_equal @person.save, false
  end

  def test_should_mark_as_invalid
    assert !@person.valid?
  end

  def test_should_parse_xml_errors
    assert_kind_of ActiveResource::Errors, @person.errors
    assert_equal 4, @person.errors.size
  end

  def test_should_parse_errors_to_individual_attributes
    assert @person.errors.invalid?(:name)    
    assert_equal "can't be blank", @person.errors.on(:age)
    assert_equal ["can't be blank", "must start with a letter"], @person.errors[:name]
    assert_equal "Person quota full for today.", @person.errors.on_base
  end

  def test_should_iterate_over_errors
    errors = []
    @person.errors.each { |attribute, message| errors << [attribute, message] }
    assert errors.include?(["name", "can't be blank"])
  end

  def test_should_iterate_over_full_errors
    errors = []
    @person.errors.each_full { |message| errors << message }
    assert errors.include?("Name can't be blank")
  end

  def test_should_format_full_errors
    full = @person.errors.full_messages
    assert full.include?("Age can't be blank")
    assert full.include?("Name can't be blank")
    assert full.include?("Name must start with a letter")
    assert full.include?("Person quota full for today.")
  end
end
