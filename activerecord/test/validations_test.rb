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
    Topic.validates_confirmation_of(:title)

    t = Topic.create("title" => "We should be confirmed")
    assert !t.save

    t.title_confirmation = "We should be confirmed"
    assert t.save
  end

  def test_terms_of_service_agreement
    Topic.validates_acceptance_of(:terms_of_service, :on => :create)

    t = Topic.create("title" => "We should be confirmed")
    assert !t.save
    assert_equal "must be accepted", t.errors.on(:terms_of_service)

    t.terms_of_service = "1"
    assert t.save
  end


  def test_eula
    Topic.validates_acceptance_of(:eula, :message => "must be abided", :on => :create)

    t = Topic.create("title" => "We should be confirmed")
    assert !t.save
    assert_equal "must be abided", t.errors.on(:eula)

    t.eula = "1"
    assert t.save
  end
  
  def test_validate_presences
    Topic.validates_presence_of(:title, :content)

    t = Topic.create
    assert !t.save
    assert_equal "can't be empty", t.errors.on(:title)
    assert_equal "can't be empty", t.errors.on(:content)
    
    t.title = "something"
    t.content  = "another"
    
    assert t.save
  end
  
  def test_validate_uniqueness
    Topic.validates_uniqueness_of(:title)
    
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

  def test_validate_format
    Topic.validates_format_of(:title, :content, :with => /^Validation macros rule!$/, :message => "is bad data")

    t = Topic.create("title" => "i'm incorrect", "content" => "Validation macros rule!")
    assert !t.valid?, "Shouldn't be valid"
    assert !t.save, "Shouldn't save because it's invalid"
    assert_equal "is bad data", t.errors.on(:title)
    assert_nil t.errors.on(:content)

    t.title = "Validation macros rule!"

    assert t.save
    assert_nil t.errors.on(:title)

    assert_raise(ArgumentError) { Topic.validates_format_of(:title, :content) }
  end

  def test_validates_inclusion_of
    Topic.validates_inclusion_of( :title, :in => %w( a b c d e f g ) )

    assert !Topic.create("title" => "a!", "content" => "abc").valid?
    assert !Topic.create("title" => "a b", "content" => "abc").valid?
    assert !Topic.create("title" => nil, "content" => "def").valid?
    assert !Topic.create("title" => %w(a b c), "content" => "def").valid?
    
    t = Topic.create("title" => "a", "content" => "I know you are but what am I?")
    assert t.valid?
    t.title = "uhoh"
    assert !t.valid?
    assert t.errors.on(:title)
    assert_equal "is not included in the list", t.errors["title"]

    assert_raise(ArgumentError) { Topic.validates_inclusion_of( :title, :in => nil ) }
    assert_raise(ArgumentError) { Topic.validates_inclusion_of( :title, :in => 0) }

    assert_nothing_raised(ArgumentError) { Topic.validates_inclusion_of( :title, :in => "hi!" ) }
    assert_nothing_raised(ArgumentError) { Topic.validates_inclusion_of( :title, :in => {} ) }
    assert_nothing_raised(ArgumentError) { Topic.validates_inclusion_of( :title, :in => [] ) }
  end

  def test_validates_length_of_using_minimum
    Topic.validates_length_of( :title, :minimum=>5 )
    t = Topic.create("title" => "valid", "content" => "whatever")
    assert t.valid?
    t.title = "not"
    assert !t.valid?
    assert t.errors.on(:title)
    assert_equal "is too short (min is 5 characters)", t.errors["title"]
    t.title = ""
    assert !t.valid?
    assert t.errors.on(:title)
    t.title = nil
    assert !t.valid?
    assert_equal "is too short (min is 5 characters)", t.errors["title"]
    assert t.errors.on(:title)
  end
  
  def test_validates_length_of_using_maximum
    Topic.validates_length_of( :title, :maximum=>5 )
    t = Topic.create("title" => "valid", "content" => "whatever")
    assert t.valid?
    t.title = "notvalid"
    assert !t.valid?
    assert t.errors.on(:title)
    assert_equal "is too long (max is 5 characters)", t.errors["title"]
    t.title = ""
    assert t.valid?
    t.title = nil
    assert t.valid?
  end

  def test_validates_length_of_using_within
    Topic.validates_length_of(:title, :content, :within => 3..5)

    t = Topic.create("title" => "a!", "content" => "I'm ooooooooh so very long")
    assert !t.save
    assert_equal "is too short (min is 3 characters)", t.errors.on(:title)
    assert_equal "is too long (max is 5 characters)", t.errors.on(:content)

    t.title = "abe"
    t.content  = "mad"

    assert t.save
  end

  def test_validates_length_of_using_is
    Topic.validates_length_of( :title, :is=>5 )
    t = Topic.create("title" => "valid", "content" => "whatever")
    assert t.valid?
    t.title = "notvalid"
    assert !t.valid?
    assert t.errors.on(:title)
    assert_equal "is the wrong length (should be 5 characters)", t.errors["title"]
    t.title = ""
    assert !t.valid?
    t.title = nil
    assert !t.valid?
  end

  def test_validates_length_of_nasty_params
    assert_raise(ArgumentError) { Topic.validates_length_of(:title, :minimum=>6, :maximum=>9) }
    assert_raise(ArgumentError) { Topic.validates_length_of(:title, :within=>6, :maximum=>9) }
    assert_raise(ArgumentError) { Topic.validates_length_of(:title, :within=>6, :minimum=>9) }
    assert_raise(ArgumentError) { Topic.validates_length_of(:title, :within=>6, :is=>9) }
    assert_raise(ArgumentError) { Topic.validates_length_of(:title, :minimum=>"a") }
    assert_raise(ArgumentError) { Topic.validates_length_of(:title, :maximum=>"a") }
    assert_raise(ArgumentError) { Topic.validates_length_of(:title, :within=>"a") }
    assert_raise(ArgumentError) { Topic.validates_length_of(:title, :is=>"a") }
  end

  def test_validates_length_of_custom_errors_for_minimum_with_message
    Topic.validates_length_of( :title, :minimum=>5, :message=>"boo %d" )
    t = Topic.create("title" => "uhoh", "content" => "whatever")
    assert !t.valid?
    assert t.errors.on(:title)
    assert_equal "boo 5", t.errors["title"]
  end

  def test_validates_length_of_custom_errors_for_minimum_with_too_short
    Topic.validates_length_of( :title, :minimum=>5, :too_short=>"hoo %d" )
    t = Topic.create("title" => "uhoh", "content" => "whatever")
    assert !t.valid?
    assert t.errors.on(:title)
    assert_equal "hoo 5", t.errors["title"]
  end

  def test_validates_length_of_custom_errors_for_maximum_with_message
    Topic.validates_length_of( :title, :maximum=>5, :message=>"boo %d" )
    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    assert !t.valid?
    assert t.errors.on(:title)
    assert_equal "boo 5", t.errors["title"]
  end

  def test_validates_length_of_custom_errors_for_maximum_with_too_long
    Topic.validates_length_of( :title, :maximum=>5, :too_long=>"hoo %d" )
    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    assert !t.valid?
    assert t.errors.on(:title)
    assert_equal "hoo 5", t.errors["title"]
  end
  
  def test_validates_length_of_custom_errors_for_is_with_message
    Topic.validates_length_of( :title, :is=>5, :message=>"boo %d" )
    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    assert !t.valid?
    assert t.errors.on(:title)
    assert_equal "boo 5", t.errors["title"]
  end

  def test_validates_length_of_custom_errors_for_is_with_wrong_length
    Topic.validates_length_of( :title, :is=>5, :wrong_length=>"hoo %d" )
    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    assert !t.valid?
    assert t.errors.on(:title)
    assert_equal "hoo 5", t.errors["title"]
  end

  def test_throw_away_typing
    d = Developer.create "name" => "David", "salary" => "100,000"
    assert !d.valid?
    assert_not_equal "100,000", d.salary
    assert_equal "100,000", d.salary_before_type_cast
  end
end