require 'abstract_unit'
require 'fixtures/topic'
require 'fixtures/reply'
require 'fixtures/developer'


class ValidationsTest < Test::Unit::TestCase
  fixtures :topics, :developers

  def teardown
    Topic.write_inheritable_attribute("validate", [])
    Topic.write_inheritable_attribute("validate_on_create", [])
  end

  def test_single_field_validation
    r = Reply.new
    r.title = "There's no content!"
    assert !r.save, "A reply without content shouldn't be saveable"

    r.content = "Messa content!"
    assert r.save, "A reply with content should be saveable"
  end
  
  def test_single_attr_validation_and_error_msg
    r = Reply.new
    r.title = "There's no content!"
    r.save
    assert r.errors.invalid?("content"), "A reply without content should mark that attribute as invalid"
    assert_equal "Empty", r.errors.on("content"), "A reply without content should contain an error"
    assert_equal 1, r.errors.count
  end

  def test_double_attr_validation_and_error_msg
    r = Reply.new
    assert !r.save

    assert r.errors.invalid?("title"), "A reply without title should mark that attribute as invalid"
    assert_equal "Empty", r.errors.on("title"), "A reply without title should contain an error"

    assert r.errors.invalid?("content"), "A reply without content should mark that attribute as invalid"
    assert_equal "Empty", r.errors.on("content"), "A reply without content should contain an error"

    assert_equal 2, r.errors.count
  end
  
  def test_error_on_create
    r = Reply.new
    r.title = "Wrong Create"
    assert !r.save
    assert r.errors.invalid?("title"), "A reply with a bad title should mark that attribute as invalid"
    assert_equal "is Wrong Create", r.errors.on("title"), "A reply with a bad content should contain an error"
  end

  
  def test_error_on_update
    r = Reply.new
    r.title = "Bad"
    r.content = "Good"

    assert r.save, "First save should be successful"
    
    r.title = "Wrong Update"
    assert !r.save, "Second save should fail"
    
    assert r.errors.invalid?("title"), "A reply with a bad title should mark that attribute as invalid"
    assert_equal "is Wrong Update", r.errors.on("title"), "A reply with a bad content should contain an error"
  end
  
  def test_single_error_per_attr_iteration
    r = Reply.new
    r.save
    
    errors = []
    r.errors.each { |attr, msg| errors << [attr, msg] }
    
    assert errors.include?(["title", "Empty"])
    assert errors.include?(["content", "Empty"])
  end
  
  def test_multiple_errors_per_attr_iteration_with_full_error_composition
    r = Reply.new
    r.title   = "Wrong Create"
    r.content = "Mismatch"
    r.save
    
    errors = []
    r.errors.each_full { |error| errors << error }
    
    assert_equal "Title is Wrong Create", errors[0]
    assert_equal "Title is Content Mismatch", errors[1]
    assert_equal 2, r.errors.count
  end
  
  def test_errors_on_base
    r = Reply.new
    r.content = "Mismatch"
    r.save
    r.errors.add_to_base "Reply is not dignifying"
    
    errors = []
    r.errors.each_full { |error| errors << error }
    
    assert_equal "Reply is not dignifying", r.errors.on_base
    
    assert errors.include?("Title Empty")
    assert errors.include?("Reply is not dignifying")
    assert_equal 2, r.errors.count
  end

  def test_create_without_validation
    reply = Reply.new
    assert !reply.save
    assert reply.save(false)
  end
  
  def test_errors_on_boundary_breaking
    developer = Developer.new("name" => "xs")
    assert !developer.save
    assert_equal "is too short (min is 3 characters)", developer.errors.on("name")
    
    developer.name = "All too very long for this boundary, it really is"
    assert !developer.save
    assert_equal "is too long (max is 20 characters)", developer.errors.on("name")

    developer.name = "Just right"
    assert developer.save
  end

  def test_title_confirmation
    Topic.validate_confirmation(:title)

    t = Topic.create("title" => "We should be confirmed")
    assert !t.save

    t.title_confirmation = "We should be confirmed"
    assert t.save
  end

  def test_terms_of_service_agreement
    Topic.validate_acceptance_on_create(:terms_of_service)

    t = Topic.create("title" => "We should be confirmed")
    assert !t.save
    assert_equal "must be accepted", t.errors.on(:terms_of_service)

    t.terms_of_service = "1"
    assert t.save
  end


  def test_eula
    Topic.validate_acceptance_on_create(:eula, :message => "must be abided")

    t = Topic.create("title" => "We should be confirmed")
    assert !t.save
    assert_equal "must be abided", t.errors.on(:eula)

    t.eula = "1"
    assert t.save
  end
  
  def test_validate_presences
    Topic.validate_presence(:title, :content)

    t = Topic.create
    assert !t.save
    assert_equal "can't be empty", t.errors.on(:title)
    assert_equal "can't be empty", t.errors.on(:content)
    
    t.title = "something"
    t.content  = "another"
    
    assert t.save
  end
  
  def test_validate_uniqueness
    Topic.validate_uniqueness(:title)
    
    t = Topic.new("title" => "I'm unique!")
    assert t.save, "Should save t as unique"

    t.content = "Remaining unique"
    assert t.save, "Should still save t as unique"

    t2 = Topic.new("title" => "I'm unique!")
    assert !t2.valid?, "Shouldn't be valid"
    assert !t2.save, "Shouldn't save t2 as unique"
    assert_equal "has already been taken", t2.errors.on(:title)
    
    t2.title = "Now Im really also unique"
    assert t2.save, "Should now save t2 as unique"
  end
end