require 'abstract_unit'
require 'fixtures/project'
require 'active_support/core_ext/hash/conversions'

# The validations are tested thoroughly under ActiveModel::Validations
# This test case simply makes sure that they are all accessible by
# Active Resource objects.
class ValidationsTest < ActiveModel::TestCase
  VALID_PROJECT_HASH = { :name => "My Project", :description => "A project" }
  def setup
    @my_proj = { "person" => VALID_PROJECT_HASH }.to_json
    ActiveResource::HttpMock.respond_to do |mock|
      mock.post "/projects.json", {}, @my_proj, 201, 'Location' => '/projects/5.json'
    end
  end

  def test_validates_presence_of
    p = new_project(:name => nil)
    assert !p.valid?, "should not be a valid record without name"
    assert !p.save, "should not have saved an invalid record"
    assert_equal ["can't be blank"], p.errors[:name], "should have an error on name"

    p.name = "something"

    assert p.save, "should have saved after fixing the validation, but had: #{p.errors.inspect}"
  end

  def test_fails_save!
    p = new_project(:name => nil)
    assert_raise(ActiveResource::ResourceInvalid) { p.save! }
  end

  def test_save_without_validation
    p = new_project(:name => nil)
    assert !p.save
    assert p.save(:validate => false)
  end

  def test_validate_callback
    # we have a callback ensuring the description is longer than three letters
    p = new_project(:description => 'a')
    assert !p.valid?, "should not be a valid record when it fails a validation callback"
    assert !p.save, "should not have saved an invalid record"
    assert_equal ["must be greater than three letters long"], p.errors[:description], "should be an error on description"

    # should now allow this description
    p.description = 'abcd'
    assert p.save, "should have saved after fixing the validation, but had: #{p.errors.inspect}"
  end

  def test_client_side_validation_maximum
    project = Project.new(:description => '123456789012345')
    assert ! project.valid?
    assert_equal ['is too long (maximum is 10 characters)'], project.errors[:description]
  end

  protected

  # quickie helper to create a new project with all the required
  # attributes.
  # Pass in any params you specifically want to override
  def new_project(opts = {})
    Project.new(VALID_PROJECT_HASH.merge(opts))
  end

end

