require 'abstract_unit'
require "fixtures/person"

class BaseErrorsTest < Test::Unit::TestCase
  def setup
    ActiveResource::HttpMock.respond_to do |mock|
      mock.post "/people.xml", {}, %q(<?xml version="1.0" encoding="UTF-8"?><errors><error>Age can't be blank</error><error>Name can't be blank</error><error>Name must start with a letter</error><error>Person quota full for today.</error></errors>), 422, {'Content-Type' => 'application/xml; charset=utf-8'}
      mock.post "/people.json", {}, %q({"errors":["Age can't be blank","Name can't be blank","Name must start with a letter","Person quota full for today."]}), 422, {'Content-Type' => 'application/json; charset=utf-8'}
    end
    @person = Person.new(:name => '', :age => '')
    assert_equal @person.save, false
  end

  def test_should_mark_as_invalid
    [ :json, :xml ].each do |format|
      invalid_user_using_format(format) do
        assert !@person.valid?
      end
    end
  end

  def test_should_parse_xml_errors
    [ :json, :xml ].each do |format|
      invalid_user_using_format(format) do
        assert_kind_of ActiveResource::Errors, @person.errors
        assert_equal 4, @person.errors.size
      end
    end
  end

  def test_should_parse_errors_to_individual_attributes
    [ :json, :xml ].each do |format|
      invalid_user_using_format(format) do
        assert @person.errors[:name].any?
        assert_equal "can't be blank", @person.errors[:age]
        assert_equal ["can't be blank", "must start with a letter"], @person.errors[:name]
        assert_equal "Person quota full for today.", @person.errors[:base]
      end
    end
  end

  def test_should_iterate_over_errors
    [ :json, :xml ].each do |format|
      invalid_user_using_format(format) do
        errors = []
        @person.errors.each { |attribute, message| errors << [attribute, message] }
        assert errors.include?(['name', "can't be blank"])
      end
    end
  end

  def test_should_iterate_over_full_errors
    [ :json, :xml ].each do |format|
      invalid_user_using_format(format) do
        errors = []
        @person.errors.to_a.each { |message| errors << message }
        assert errors.include?(["name", "can't be blank"])
      end
    end
  end

  def test_should_format_full_errors
    [ :json, :xml ].each do |format|
      invalid_user_using_format(format) do
        full = @person.errors.full_messages
        assert full.include?("Age can't be blank")
        assert full.include?("Name can't be blank")
        assert full.include?("Name must start with a letter")
        assert full.include?("Person quota full for today.")
      end
    end
  end

  def test_should_mark_as_invalid_when_content_type_is_unavailable_in_response_header
    ActiveResource::HttpMock.respond_to do |mock|
      mock.post "/people.xml", {}, %q(<?xml version="1.0" encoding="UTF-8"?><errors><error>Age can't be blank</error><error>Name can't be blank</error><error>Name must start with a letter</error><error>Person quota full for today.</error></errors>), 422, {}
      mock.post "/people.json", {}, %q({"errors":["Age can't be blank","Name can't be blank","Name must start with a letter","Person quota full for today."]}), 422, {}
    end

    [ :json, :xml ].each do |format|
      invalid_user_using_format(format) do
        assert !@person.valid?
      end
    end
  end

  private
  def invalid_user_using_format(mime_type_reference)
    previous_format = Person.format
    Person.format = mime_type_reference
    @person = Person.new(:name => '', :age => '')
    assert_equal false, @person.save

    yield
  ensure
    Person.format = previous_format
  end
end
