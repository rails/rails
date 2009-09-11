# encoding: utf-8
require "cases/helper"
require 'models/topic'
require 'models/reply'
require 'models/person'
require 'models/developer'
require 'models/warehouse_thing'
require 'models/guid'
require 'models/owner'
require 'models/pet'
require 'models/event'
require 'models/man'
require 'models/interest'

# The following methods in Topic are used in test_conditional_validation_*
class Topic
  has_many :unique_replies, :dependent => :destroy, :foreign_key => "parent_id"
  has_many :silly_unique_replies, :dependent => :destroy, :foreign_key => "parent_id"

  def condition_is_true
    true
  end

  def condition_is_true_but_its_not
    false
  end
end

class ProtectedPerson < ActiveRecord::Base
  set_table_name 'people'
  attr_accessor :addon
  attr_protected :first_name

  def special_error
    this_method_does_not_exist!
  rescue
    errors.add(:special_error, "This method does not exist")
  end
end

class UniqueReply < Reply
  validates_uniqueness_of :content, :scope => 'parent_id'
end

class SillyUniqueReply < UniqueReply
end

class Wizard < ActiveRecord::Base
  self.abstract_class = true

  validates_uniqueness_of :name
end

class IneptWizard < Wizard
  validates_uniqueness_of :city
end

class Conjurer < IneptWizard
end

class Thaumaturgist < IneptWizard
end


class ValidationsTest < ActiveRecord::TestCase
  fixtures :topics, :developers, 'warehouse-things'

  # Most of the tests mess with the validations of Topic, so lets repair it all the time.
  # Other classes we mess with will be dealt with in the specific tests
  repair_validations(Topic)

  def test_single_field_validation
    r = Reply.new
    r.title = "There's no content!"
    assert !r.valid?, "A reply without content shouldn't be saveable"

    r.content = "Messa content!"
    assert r.valid?, "A reply with content should be saveable"
  end

  def test_single_attr_validation_and_error_msg
    r = Reply.new
    r.title = "There's no content!"
    assert !r.valid?
    assert r.errors.invalid?("content"), "A reply without content should mark that attribute as invalid"
    assert_equal "Empty", r.errors.on("content"), "A reply without content should contain an error"
    assert_equal 1, r.errors.count
  end

  def test_double_attr_validation_and_error_msg
    r = Reply.new
    assert !r.valid?

    assert r.errors.invalid?("title"), "A reply without title should mark that attribute as invalid"
    assert_equal "Empty", r.errors.on("title"), "A reply without title should contain an error"

    assert r.errors.invalid?("content"), "A reply without content should mark that attribute as invalid"
    assert_equal "Empty", r.errors.on("content"), "A reply without content should contain an error"

    assert_equal 2, r.errors.count
  end

  def test_error_on_create
    r = Reply.new
    r.title = "Wrong Create"
    assert !r.valid?
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

  def test_invalid_record_exception
    assert_raise(ActiveRecord::RecordInvalid) { Reply.create! }
    assert_raise(ActiveRecord::RecordInvalid) { Reply.new.save! }

    begin
      r = Reply.new
      r.save!
      flunk
    rescue ActiveRecord::RecordInvalid => invalid
      assert_equal r, invalid.record
    end
  end

  def test_exception_on_create_bang_many
    assert_raise(ActiveRecord::RecordInvalid) do
      Reply.create!([ { "title" => "OK" }, { "title" => "Wrong Create" }])
    end
  end

  def test_exception_on_create_bang_with_block
    assert_raise(ActiveRecord::RecordInvalid) do
      Reply.create!({ "title" => "OK" }) do |r|
        r.content = nil
      end
    end
  end

  def test_exception_on_create_bang_many_with_block
    assert_raise(ActiveRecord::RecordInvalid) do
      Reply.create!([{ "title" => "OK" }, { "title" => "Wrong Create" }]) do |r|
        r.content = nil
      end
    end
  end

  def test_scoped_create_without_attributes
    Reply.with_scope(:create => {}) do
      assert_raise(ActiveRecord::RecordInvalid) { Reply.create! }
    end
  end

  def test_create_with_exceptions_using_scope_for_protected_attributes
    assert_nothing_raised do
      ProtectedPerson.with_scope( :create => { :first_name => "Mary" } ) do
        person = ProtectedPerson.create! :addon => "Addon"
        assert_equal person.first_name, "Mary", "scope should ignore attr_protected"
      end
    end
  end

  def test_create_with_exceptions_using_scope_and_empty_attributes
    assert_nothing_raised do
      ProtectedPerson.with_scope( :create => { :first_name => "Mary" } ) do
        person = ProtectedPerson.create!
        assert_equal person.first_name, "Mary", "should be ok when no attributes are passed to create!"
      end
    end
  end

  def test_values_are_not_retrieved_unless_needed
    assert_nothing_raised do
      person = ProtectedPerson.new
      person.special_error
      assert_equal "This method does not exist", person.errors[:special_error]
    end
  end

  def test_single_error_string_per_attr_iteration
    r = Reply.new
    r.save

    errors = []
    r.errors.each { |attr, msg| errors << [attr, msg] }

    assert errors.include?(["title", "Empty"])
    assert errors.include?(["content", "Empty"])
  end

  def test_single_error_object_per_attr_iteration
    r = Reply.new
    r.save

    errors = []
    r.errors.each_error { |attr, error| errors << [attr, error.attribute] }

    assert errors.include?(["title", "title"])
    assert errors.include?(["content", "content"])
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

  def test_create_without_validation_bang
    count = Reply.count
    assert_nothing_raised { Reply.new.save_without_validation! }
    assert count+1, Reply.count
  end

  def test_validates_each
    hits = 0
    Topic.validates_each(:title, :content, [:title, :content]) do |record, attr|
      record.errors.add attr, 'gotcha'
      hits += 1
    end
    t = Topic.new("title" => "valid", "content" => "whatever")
    assert !t.save
    assert_equal 4, hits
    assert_equal %w(gotcha gotcha), t.errors.on(:title)
    assert_equal %w(gotcha gotcha), t.errors.on(:content)
  end

  def test_no_title_confirmation
    Topic.validates_confirmation_of(:title)

    t = Topic.new(:author_name => "Plutarch")
    assert t.valid?

    t.title_confirmation = "Parallel Lives"
    assert !t.valid?

    t.title_confirmation = nil
    t.title = "Parallel Lives"
    assert t.valid?

    t.title_confirmation = "Parallel Lives"
    assert t.valid?
  end

  def test_title_confirmation
    Topic.validates_confirmation_of(:title)

    t = Topic.create("title" => "We should be confirmed","title_confirmation" => "")
    assert !t.save

    t.title_confirmation = "We should be confirmed"
    assert t.save
  end

  def test_terms_of_service_agreement_no_acceptance
    Topic.validates_acceptance_of(:terms_of_service, :on => :create)

    t = Topic.create("title" => "We should not be confirmed")
    assert t.save
  end

  def test_terms_of_service_agreement
    Topic.validates_acceptance_of(:terms_of_service, :on => :create)

    t = Topic.create("title" => "We should be confirmed","terms_of_service" => "")
    assert !t.save
    assert_equal "must be accepted", t.errors.on(:terms_of_service)

    t.terms_of_service = "1"
    assert t.save
  end


  def test_eula
    Topic.validates_acceptance_of(:eula, :message => "must be abided", :on => :create)

    t = Topic.create("title" => "We should be confirmed","eula" => "")
    assert !t.save
    assert_equal "must be abided", t.errors.on(:eula)

    t.eula = "1"
    assert t.save
  end

  def test_terms_of_service_agreement_with_accept_value
    Topic.validates_acceptance_of(:terms_of_service, :on => :create, :accept => "I agree.")

    t = Topic.create("title" => "We should be confirmed", "terms_of_service" => "")
    assert !t.save
    assert_equal "must be accepted", t.errors.on(:terms_of_service)

    t.terms_of_service = "I agree."
    assert t.save
  end

  def test_validates_acceptance_of_as_database_column
    repair_validations(Reply) do
      Reply.validates_acceptance_of(:author_name)

      reply = Reply.create("author_name" => "Dan Brown")
      assert_equal "Dan Brown", reply["author_name"]
    end
  end

  def test_validates_acceptance_of_with_non_existant_table
    Object.const_set :IncorporealModel, Class.new(ActiveRecord::Base)

    assert_nothing_raised ActiveRecord::StatementInvalid do
      IncorporealModel.validates_acceptance_of(:incorporeal_column)
    end
  end

  def test_validate_presences
    Topic.validates_presence_of(:title, :content)

    t = Topic.create
    assert !t.save
    assert_equal "can't be blank", t.errors.on(:title)
    assert_equal "can't be blank", t.errors.on(:content)

    t.title = "something"
    t.content  = "   "

    assert !t.save
    assert_equal "can't be blank", t.errors.on(:content)

    t.content = "like stuff"

    assert t.save
  end

  def test_validates_presence_of_belongs_to_association__parent_is_new_record
    repair_validations(Interest) do
      # Note that Interest and Man have the :inverse_of option set
      Interest.validates_presence_of(:man)
      man = Man.new(:name => 'John')
      interest = man.interests.build(:topic => 'Airplanes')
      assert interest.valid?, "Expected interest to be valid, but was not. Interest should have a man object associated"
    end
  end

  def test_validates_presence_of_belongs_to_association__existing_parent
    repair_validations(Interest) do
      Interest.validates_presence_of(:man)
      man = Man.create!(:name => 'John')
      interest = man.interests.build(:topic => 'Airplanes')
      assert interest.valid?, "Expected interest to be valid, but was not. Interest should have a man object associated"
    end
  end

  def test_validate_uniqueness
    Topic.validates_uniqueness_of(:title)

    t = Topic.new("title" => "I'm uniqué!")
    assert t.save, "Should save t as unique"

    t.content = "Remaining unique"
    assert t.save, "Should still save t as unique"

    t2 = Topic.new("title" => "I'm uniqué!")
    assert !t2.valid?, "Shouldn't be valid"
    assert !t2.save, "Shouldn't save t2 as unique"
    assert_equal "has already been taken", t2.errors.on(:title)

    t2.title = "Now Im really also unique"
    assert t2.save, "Should now save t2 as unique"
  end

  def test_validates_uniquness_with_newline_chars
    Topic.validates_uniqueness_of(:title, :case_sensitive => false)

    t = Topic.new("title" => "new\nline")
    assert t.save, "Should save t as unique"
  end

  def test_validate_uniqueness_with_scope
    repair_validations(Reply) do
      Reply.validates_uniqueness_of(:content, :scope => "parent_id")

      t = Topic.create("title" => "I'm unique!")

      r1 = t.replies.create "title" => "r1", "content" => "hello world"
      assert r1.valid?, "Saving r1"

      r2 = t.replies.create "title" => "r2", "content" => "hello world"
      assert !r2.valid?, "Saving r2 first time"

      r2.content = "something else"
      assert r2.save, "Saving r2 second time"

      t2 = Topic.create("title" => "I'm unique too!")
      r3 = t2.replies.create "title" => "r3", "content" => "hello world"
      assert r3.valid?, "Saving r3"
    end
  end

  def test_validate_uniqueness_scoped_to_defining_class
    t = Topic.create("title" => "What, me worry?")

    r1 = t.unique_replies.create "title" => "r1", "content" => "a barrel of fun"
    assert r1.valid?, "Saving r1"

    r2 = t.silly_unique_replies.create "title" => "r2", "content" => "a barrel of fun"
    assert !r2.valid?, "Saving r2"

    # Should succeed as validates_uniqueness_of only applies to
    # UniqueReply and its subclasses
    r3 = t.replies.create "title" => "r2", "content" => "a barrel of fun"
    assert r3.valid?, "Saving r3"
  end

  def test_validate_uniqueness_with_scope_array
    repair_validations(Reply) do
      Reply.validates_uniqueness_of(:author_name, :scope => [:author_email_address, :parent_id])

      t = Topic.create("title" => "The earth is actually flat!")

      r1 = t.replies.create "author_name" => "jeremy", "author_email_address" => "jeremy@rubyonrails.com", "title" => "You're crazy!", "content" => "Crazy reply"
      assert r1.valid?, "Saving r1"

      r2 = t.replies.create "author_name" => "jeremy", "author_email_address" => "jeremy@rubyonrails.com", "title" => "You're crazy!", "content" => "Crazy reply again..."
      assert !r2.valid?, "Saving r2. Double reply by same author."

      r2.author_email_address = "jeremy_alt_email@rubyonrails.com"
      assert r2.save, "Saving r2 the second time."

      r3 = t.replies.create "author_name" => "jeremy", "author_email_address" => "jeremy_alt_email@rubyonrails.com", "title" => "You're wrong", "content" => "It's cubic"
      assert !r3.valid?, "Saving r3"

      r3.author_name = "jj"
      assert r3.save, "Saving r3 the second time."

      r3.author_name = "jeremy"
      assert !r3.save, "Saving r3 the third time."
    end
  end

  def test_validate_case_insensitive_uniqueness
    Topic.validates_uniqueness_of(:title, :parent_id, :case_sensitive => false, :allow_nil => true)

    t = Topic.new("title" => "I'm unique!", :parent_id => 2)
    assert t.save, "Should save t as unique"

    t.content = "Remaining unique"
    assert t.save, "Should still save t as unique"

    t2 = Topic.new("title" => "I'm UNIQUE!", :parent_id => 1)
    assert !t2.valid?, "Shouldn't be valid"
    assert !t2.save, "Shouldn't save t2 as unique"
    assert t2.errors.on(:title)
    assert t2.errors.on(:parent_id)
    assert_equal "has already been taken", t2.errors.on(:title)

    t2.title = "I'm truly UNIQUE!"
    assert !t2.valid?, "Shouldn't be valid"
    assert !t2.save, "Shouldn't save t2 as unique"
    assert_nil t2.errors.on(:title)
    assert t2.errors.on(:parent_id)

    t2.parent_id = 4
    assert t2.save, "Should now save t2 as unique"

    t2.parent_id = nil
    t2.title = nil
    assert t2.valid?, "should validate with nil"
    assert t2.save, "should save with nil"

    with_kcode('UTF8') do
      t_utf8 = Topic.new("title" => "Я тоже уникальный!")
      assert t_utf8.save, "Should save t_utf8 as unique"

      # If database hasn't UTF-8 character set, this test fails
      if Topic.find(t_utf8, :select => 'LOWER(title) AS title').title == "я тоже уникальный!"
        t2_utf8 = Topic.new("title" => "я тоже УНИКАЛЬНЫЙ!")
        assert !t2_utf8.valid?, "Shouldn't be valid"
        assert !t2_utf8.save, "Shouldn't save t2_utf8 as unique"
      end
    end
  end

  def test_validate_case_sensitive_uniqueness
    Topic.validates_uniqueness_of(:title, :case_sensitive => true, :allow_nil => true)

    t = Topic.new("title" => "I'm unique!")
    assert t.save, "Should save t as unique"

    t.content = "Remaining unique"
    assert t.save, "Should still save t as unique"

    t2 = Topic.new("title" => "I'M UNIQUE!")
    assert t2.valid?, "Should be valid"
    assert t2.save, "Should save t2 as unique"
    assert !t2.errors.on(:title)
    assert !t2.errors.on(:parent_id)
    assert_not_equal "has already been taken", t2.errors.on(:title)

    t3 = Topic.new("title" => "I'M uNiQUe!")
    assert t3.valid?, "Should be valid"
    assert t3.save, "Should save t2 as unique"
    assert !t3.errors.on(:title)
    assert !t3.errors.on(:parent_id)
    assert_not_equal "has already been taken", t3.errors.on(:title)
  end

  def test_validate_case_sensitive_uniqueness_with_attribute_passed_as_integer
    Topic.validates_uniqueness_of(:title, :case_sensitve => true)
    t = Topic.create!('title' => 101)

    t2 = Topic.new('title' => 101)
    assert !t2.valid?
    assert t2.errors.on(:title)
  end

  def test_validate_uniqueness_with_non_standard_table_names
    i1 = WarehouseThing.create(:value => 1000)
    assert !i1.valid?, "i1 should not be valid"
    assert i1.errors.on(:value), "Should not be empty"
  end

  def test_validates_uniqueness_inside_with_scope
    Topic.validates_uniqueness_of(:title)

    Topic.with_scope(:find => { :conditions => { :author_name => "David" } }) do
      t1 = Topic.new("title" => "I'm unique!", "author_name" => "Mary")
      assert t1.save
      t2 = Topic.new("title" => "I'm unique!", "author_name" => "David")
      assert !t2.valid?
    end
  end

  def test_validate_uniqueness_with_columns_which_are_sql_keywords
    repair_validations(Guid) do
      Guid.validates_uniqueness_of :key
      g = Guid.new
      g.key = "foo"
      assert_nothing_raised { !g.valid? }
    end
  end

  def test_validate_uniqueness_with_limit
    # Event.title is limited to 5 characters
    e1 = Event.create(:title => "abcde")
    assert e1.valid?, "Could not create an event with a unique, 5 character title"
    e2 = Event.create(:title => "abcdefgh")
    assert !e2.valid?, "Created an event whose title, with limit taken into account, is not unique"
  end

  def test_validate_uniqueness_with_limit_and_utf8
    with_kcode('UTF8') do
      # Event.title is limited to 5 characters
      e1 = Event.create(:title => "一二三四五")
      assert e1.valid?, "Could not create an event with a unique, 5 character title"
      e2 = Event.create(:title => "一二三四五六七八")
      assert !e2.valid?, "Created an event whose title, with limit taken into account, is not unique"
    end
  end

  def test_validate_straight_inheritance_uniqueness
    w1 = IneptWizard.create(:name => "Rincewind", :city => "Ankh-Morpork")
    assert w1.valid?, "Saving w1"

    # Should use validation from base class (which is abstract)
    w2 = IneptWizard.new(:name => "Rincewind", :city => "Quirm")
    assert !w2.valid?, "w2 shouldn't be valid"
    assert w2.errors.on(:name), "Should have errors for name"
    assert_equal "has already been taken", w2.errors.on(:name), "Should have uniqueness message for name"

    w3 = Conjurer.new(:name => "Rincewind", :city => "Quirm")
    assert !w3.valid?, "w3 shouldn't be valid"
    assert w3.errors.on(:name), "Should have errors for name"
    assert_equal "has already been taken", w3.errors.on(:name), "Should have uniqueness message for name"

    w4 = Conjurer.create(:name => "The Amazing Bonko", :city => "Quirm")
    assert w4.valid?, "Saving w4"

    w5 = Thaumaturgist.new(:name => "The Amazing Bonko", :city => "Lancre")
    assert !w5.valid?, "w5 shouldn't be valid"
    assert w5.errors.on(:name), "Should have errors for name"
    assert_equal "has already been taken", w5.errors.on(:name), "Should have uniqueness message for name"

    w6 = Thaumaturgist.new(:name => "Mustrum Ridcully", :city => "Quirm")
    assert !w6.valid?, "w6 shouldn't be valid"
    assert w6.errors.on(:city), "Should have errors for city"
    assert_equal "has already been taken", w6.errors.on(:city), "Should have uniqueness message for city"
  end

  def test_validate_format
    Topic.validates_format_of(:title, :content, :with => /^Validation\smacros \w+!$/, :message => "is bad data")

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

  def test_validate_format_with_allow_blank
    Topic.validates_format_of(:title, :with => /^Validation\smacros \w+!$/, :allow_blank=>true)
    assert !Topic.create("title" => "Shouldn't be valid").valid?
    assert Topic.create("title" => "").valid?
    assert Topic.create("title" => nil).valid?
    assert Topic.create("title" => "Validation macros rule!").valid?
  end

  # testing ticket #3142
  def test_validate_format_numeric
    Topic.validates_format_of(:title, :content, :with => /^[1-9][0-9]*$/, :message => "is bad data")

    t = Topic.create("title" => "72x", "content" => "6789")
    assert !t.valid?, "Shouldn't be valid"
    assert !t.save, "Shouldn't save because it's invalid"
    assert_equal "is bad data", t.errors.on(:title)
    assert_nil t.errors.on(:content)

    t.title = "-11"
    assert !t.valid?, "Shouldn't be valid"

    t.title = "03"
    assert !t.valid?, "Shouldn't be valid"

    t.title = "z44"
    assert !t.valid?, "Shouldn't be valid"

    t.title = "5v7"
    assert !t.valid?, "Shouldn't be valid"

    t.title = "1"

    assert t.save
    assert_nil t.errors.on(:title)
  end

  def test_validate_format_with_formatted_message
    Topic.validates_format_of(:title, :with => /^Valid Title$/, :message => "can't be {{value}}")
    t = Topic.create(:title => 'Invalid title')
    assert_equal "can't be Invalid title", t.errors.on(:title)
  end

  def test_validates_inclusion_of
    Topic.validates_inclusion_of( :title, :in => %w( a b c d e f g ) )

    assert !Topic.create("title" => "a!", "content" => "abc").valid?
    assert !Topic.create("title" => "a b", "content" => "abc").valid?
    assert !Topic.create("title" => nil, "content" => "def").valid?

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

  def test_validates_inclusion_of_with_allow_nil
    Topic.validates_inclusion_of( :title, :in => %w( a b c d e f g ), :allow_nil=>true )

    assert !Topic.create("title" => "a!", "content" => "abc").valid?
    assert !Topic.create("title" => "", "content" => "abc").valid?
    assert Topic.create("title" => nil, "content" => "abc").valid?
  end

  def test_numericality_with_getter_method
    repair_validations(Developer) do
      Developer.validates_numericality_of( :salary )
      developer = Developer.new("name" => "michael", "salary" => nil)
      developer.instance_eval("def salary; read_attribute('salary') ? read_attribute('salary') : 100000; end")
      assert developer.valid?
    end
  end

  def test_validates_length_of_with_allow_nil
    Topic.validates_length_of( :title, :is => 5, :allow_nil=>true )

    assert !Topic.create("title" => "ab").valid?
    assert !Topic.create("title" => "").valid?
    assert Topic.create("title" => nil).valid?
    assert Topic.create("title" => "abcde").valid?
  end

  def test_validates_length_of_with_allow_blank
    Topic.validates_length_of( :title, :is => 5, :allow_blank=>true )

    assert !Topic.create("title" => "ab").valid?
    assert Topic.create("title" => "").valid?
    assert Topic.create("title" => nil).valid?
    assert Topic.create("title" => "abcde").valid?
  end

  def test_validates_inclusion_of_with_formatted_message
    Topic.validates_inclusion_of( :title, :in => %w( a b c d e f g ), :message => "option {{value}} is not in the list" )

    assert Topic.create("title" => "a", "content" => "abc").valid?

    t = Topic.create("title" => "uhoh", "content" => "abc")
    assert !t.valid?
    assert t.errors.on(:title)
    assert_equal "option uhoh is not in the list", t.errors["title"]
  end

  def test_numericality_with_allow_nil_and_getter_method
    repair_validations(Developer) do
      Developer.validates_numericality_of( :salary, :allow_nil => true)
      developer = Developer.new("name" => "michael", "salary" => nil)
      developer.instance_eval("def salary; read_attribute('salary') ? read_attribute('salary') : 100000; end")
      assert developer.valid?
    end
  end

  def test_validates_exclusion_of
    Topic.validates_exclusion_of( :title, :in => %w( abe monkey ) )

    assert Topic.create("title" => "something", "content" => "abc").valid?
    assert !Topic.create("title" => "monkey", "content" => "abc").valid?
  end

  def test_validates_exclusion_of_with_formatted_message
    Topic.validates_exclusion_of( :title, :in => %w( abe monkey ), :message => "option {{value}} is restricted" )

    assert Topic.create("title" => "something", "content" => "abc")

    t = Topic.create("title" => "monkey")
    assert !t.valid?
    assert t.errors.on(:title)
    assert_equal "option monkey is restricted", t.errors["title"]
  end

  def test_validates_length_of_using_minimum
    Topic.validates_length_of :title, :minimum => 5

    t = Topic.create("title" => "valid", "content" => "whatever")
    assert t.valid?

    t.title = "not"
    assert !t.valid?
    assert t.errors.on(:title)
    assert_equal "is too short (minimum is 5 characters)", t.errors["title"]

    t.title = ""
    assert !t.valid?
    assert t.errors.on(:title)
    assert_equal "is too short (minimum is 5 characters)", t.errors["title"]

    t.title = nil
    assert !t.valid?
    assert t.errors.on(:title)
    assert_equal "is too short (minimum is 5 characters)", t.errors["title"]
  end

  def test_optionally_validates_length_of_using_minimum
    Topic.validates_length_of :title, :minimum => 5, :allow_nil => true

    t = Topic.create("title" => "valid", "content" => "whatever")
    assert t.valid?

    t.title = nil
    assert t.valid?
  end

  def test_validates_length_of_using_maximum
    Topic.validates_length_of :title, :maximum => 5

    t = Topic.create("title" => "valid", "content" => "whatever")
    assert t.valid?

    t.title = "notvalid"
    assert !t.valid?
    assert t.errors.on(:title)
    assert_equal "is too long (maximum is 5 characters)", t.errors["title"]

    t.title = ""
    assert t.valid?

    t.title = nil
    assert !t.valid?
  end

  def test_optionally_validates_length_of_using_maximum
    Topic.validates_length_of :title, :maximum => 5, :allow_nil => true

    t = Topic.create("title" => "valid", "content" => "whatever")
    assert t.valid?

    t.title = nil
    assert t.valid?
  end

  def test_validates_length_of_using_within
    Topic.validates_length_of(:title, :content, :within => 3..5)

    t = Topic.new("title" => "a!", "content" => "I'm ooooooooh so very long")
    assert !t.valid?
    assert_equal "is too short (minimum is 3 characters)", t.errors.on(:title)
    assert_equal "is too long (maximum is 5 characters)", t.errors.on(:content)

    t.title = nil
    t.content = nil
    assert !t.valid?
    assert_equal "is too short (minimum is 3 characters)", t.errors.on(:title)
    assert_equal "is too short (minimum is 3 characters)", t.errors.on(:content)

    t.title = "abe"
    t.content  = "mad"
    assert t.valid?
  end

  def test_optionally_validates_length_of_using_within
    Topic.validates_length_of :title, :content, :within => 3..5, :allow_nil => true

    t = Topic.create('title' => 'abc', 'content' => 'abcd')
    assert t.valid?

    t.title = nil
    assert t.valid?
  end

  def test_optionally_validates_length_of_using_within_on_create
    Topic.validates_length_of :title, :content, :within => 5..10, :on => :create, :too_long => "my string is too long: {{count}}"

    t = Topic.create("title" => "thisisnotvalid", "content" => "whatever")
    assert !t.save
    assert t.errors.on(:title)
    assert_equal "my string is too long: 10", t.errors[:title]

    t.title = "butthisis"
    assert t.save

    t.title = "few"
    assert t.save

    t.content = "andthisislong"
    assert t.save

    t.content = t.title = "iamfine"
    assert t.save
  end

  def test_optionally_validates_length_of_using_within_on_update
    Topic.validates_length_of :title, :content, :within => 5..10, :on => :update, :too_short => "my string is too short: {{count}}"

    t = Topic.create("title" => "vali", "content" => "whatever")
    assert !t.save
    assert t.errors.on(:title)

    t.title = "not"
    assert !t.save
    assert t.errors.on(:title)
    assert_equal "my string is too short: 5", t.errors[:title]

    t.title = "valid"
    t.content = "andthisistoolong"
    assert !t.save
    assert t.errors.on(:content)

    t.content = "iamfine"
    assert t.save
  end

  def test_validates_length_of_using_is
    Topic.validates_length_of :title, :is => 5

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

  def test_optionally_validates_length_of_using_is
    Topic.validates_length_of :title, :is => 5, :allow_nil => true

    t = Topic.create("title" => "valid", "content" => "whatever")
    assert t.valid?

    t.title = nil
    assert t.valid?
  end

  def test_validates_length_of_using_bignum
    bigmin = 2 ** 30
    bigmax = 2 ** 32
    bigrange = bigmin...bigmax
    assert_nothing_raised do
      Topic.validates_length_of :title, :is => bigmin + 5
      Topic.validates_length_of :title, :within => bigrange
      Topic.validates_length_of :title, :in => bigrange
      Topic.validates_length_of :title, :minimum => bigmin
      Topic.validates_length_of :title, :maximum => bigmax
    end
  end

  def test_validates_length_with_globally_modified_error_message
    defaults = ActiveSupport::Deprecation.silence { ActiveRecord::Errors.default_error_messages }
    original_message = defaults[:too_short]
    defaults[:too_short] = 'tu est trops petit hombre {{count}}'

    Topic.validates_length_of :title, :minimum => 10
    t = Topic.create(:title => 'too short')
    assert !t.valid?

    assert_equal 'tu est trops petit hombre 10', t.errors['title']

  ensure
    defaults[:too_short] = original_message
  end

  def test_validates_size_of_association
    repair_validations(Owner) do
      assert_nothing_raised { Owner.validates_size_of :pets, :minimum => 1 }
      o = Owner.new('name' => 'nopets')
      assert !o.save
      assert o.errors.on(:pets)
      pet = o.pets.build('name' => 'apet')
      assert o.valid?
    end
  end

  def test_validates_size_of_association_using_within
    repair_validations(Owner) do
      assert_nothing_raised { Owner.validates_size_of :pets, :within => 1..2 }
      o = Owner.new('name' => 'nopets')
      assert !o.save
      assert o.errors.on(:pets)

      pet = o.pets.build('name' => 'apet')
      assert o.valid?

      2.times { o.pets.build('name' => 'apet') }
      assert !o.save
      assert o.errors.on(:pets)
    end
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
    Topic.validates_length_of( :title, :minimum=>5, :message=>"boo {{count}}" )
    t = Topic.create("title" => "uhoh", "content" => "whatever")
    assert !t.valid?
    assert t.errors.on(:title)
    assert_equal "boo 5", t.errors["title"]
  end

  def test_validates_length_of_custom_errors_for_minimum_with_too_short
    Topic.validates_length_of( :title, :minimum=>5, :too_short=>"hoo {{count}}" )
    t = Topic.create("title" => "uhoh", "content" => "whatever")
    assert !t.valid?
    assert t.errors.on(:title)
    assert_equal "hoo 5", t.errors["title"]
  end

  def test_validates_length_of_custom_errors_for_maximum_with_message
    Topic.validates_length_of( :title, :maximum=>5, :message=>"boo {{count}}" )
    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    assert !t.valid?
    assert t.errors.on(:title)
    assert_equal "boo 5", t.errors["title"]
  end

  def test_validates_length_of_custom_errors_for_in
    Topic.validates_length_of(:title, :in => 10..20, :message => "hoo {{count}}")
    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    assert !t.valid?
    assert t.errors.on(:title)
    assert_equal "hoo 10", t.errors["title"]

    t = Topic.create("title" => "uhohuhohuhohuhohuhohuhohuhohuhoh", "content" => "whatever")
    assert !t.valid?
    assert t.errors.on(:title)
    assert_equal "hoo 20", t.errors["title"]
  end

  def test_validates_length_of_custom_errors_for_maximum_with_too_long
    Topic.validates_length_of( :title, :maximum=>5, :too_long=>"hoo {{count}}" )
    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    assert !t.valid?
    assert t.errors.on(:title)
    assert_equal "hoo 5", t.errors["title"]
  end

  def test_validates_length_of_custom_errors_for_is_with_message
    Topic.validates_length_of( :title, :is=>5, :message=>"boo {{count}}" )
    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    assert !t.valid?
    assert t.errors.on(:title)
    assert_equal "boo 5", t.errors["title"]
  end

  def test_validates_length_of_custom_errors_for_is_with_wrong_length
    Topic.validates_length_of( :title, :is=>5, :wrong_length=>"hoo {{count}}" )
    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    assert !t.valid?
    assert t.errors.on(:title)
    assert_equal "hoo 5", t.errors["title"]
  end

  def test_validates_length_of_using_minimum_utf8
    with_kcode('UTF8') do
      Topic.validates_length_of :title, :minimum => 5

      t = Topic.create("title" => "一二三四五", "content" => "whatever")
      assert t.valid?

      t.title = "一二三四"
      assert !t.valid?
      assert t.errors.on(:title)
      assert_equal "is too short (minimum is 5 characters)", t.errors["title"]
    end
  end

  def test_validates_length_of_using_maximum_utf8
    with_kcode('UTF8') do
      Topic.validates_length_of :title, :maximum => 5

      t = Topic.create("title" => "一二三四五", "content" => "whatever")
      assert t.valid?

      t.title = "一二34五六"
      assert !t.valid?
      assert t.errors.on(:title)
      assert_equal "is too long (maximum is 5 characters)", t.errors["title"]
    end
  end

  def test_validates_length_of_using_within_utf8
    with_kcode('UTF8') do
      Topic.validates_length_of(:title, :content, :within => 3..5)

      t = Topic.new("title" => "一二", "content" => "12三四五六七")
      assert !t.valid?
      assert_equal "is too short (minimum is 3 characters)", t.errors.on(:title)
      assert_equal "is too long (maximum is 5 characters)", t.errors.on(:content)
      t.title = "一二三"
      t.content  = "12三"
      assert t.valid?
    end
  end

  def test_optionally_validates_length_of_using_within_utf8
    with_kcode('UTF8') do
      Topic.validates_length_of :title, :within => 3..5, :allow_nil => true

      t = Topic.create(:title => "一二三四五")
      assert t.valid?, t.errors.inspect

      t = Topic.create(:title => "一二三")
      assert t.valid?, t.errors.inspect

      t.title = nil
      assert t.valid?, t.errors.inspect
    end
  end

  def test_optionally_validates_length_of_using_within_on_create_utf8
    with_kcode('UTF8') do
      Topic.validates_length_of :title, :within => 5..10, :on => :create, :too_long => "長すぎます: {{count}}"

      t = Topic.create("title" => "一二三四五六七八九十A", "content" => "whatever")
      assert !t.save
      assert t.errors.on(:title)
      assert_equal "長すぎます: 10", t.errors[:title]

      t.title = "一二三四五六七八九"
      assert t.save

      t.title = "一二3"
      assert t.save

      t.content = "一二三四五六七八九十"
      assert t.save

      t.content = t.title = "一二三四五六"
      assert t.save
    end
  end

  def test_optionally_validates_length_of_using_within_on_update_utf8
    with_kcode('UTF8') do
      Topic.validates_length_of :title, :within => 5..10, :on => :update, :too_short => "短すぎます: {{count}}"

      t = Topic.create("title" => "一二三4", "content" => "whatever")
      assert !t.save
      assert t.errors.on(:title)

      t.title = "1二三4"
      assert !t.save
      assert t.errors.on(:title)
      assert_equal "短すぎます: 5", t.errors[:title]

      t.title = "一二三四五六七八九十A"
      assert !t.save
      assert t.errors.on(:title)

      t.title = "一二345"
      assert t.save
    end
  end

  def test_validates_length_of_using_is_utf8
    with_kcode('UTF8') do
      Topic.validates_length_of :title, :is => 5

      t = Topic.create("title" => "一二345", "content" => "whatever")
      assert t.valid?

      t.title = "一二345六"
      assert !t.valid?
      assert t.errors.on(:title)
      assert_equal "is the wrong length (should be 5 characters)", t.errors["title"]
    end
  end

  def test_validates_length_of_with_block
    Topic.validates_length_of :content, :minimum => 5, :too_short=>"Your essay must be at least {{count}} words.",
                                        :tokenizer => lambda {|str| str.scan(/\w+/) }
    t = Topic.create!(:content => "this content should be long enough")
    assert t.valid?

    t.content = "not long enough"
    assert !t.valid?
    assert t.errors.on(:content)
    assert_equal "Your essay must be at least 5 words.", t.errors[:content]
  end

  def test_validates_size_of_association_utf8
    repair_validations(Owner) do
      with_kcode('UTF8') do
        assert_nothing_raised { Owner.validates_size_of :pets, :minimum => 1 }
        o = Owner.new('name' => 'あいうえおかきくけこ')
        assert !o.save
        assert o.errors.on(:pets)
        o.pets.build('name' => 'あいうえおかきくけこ')
        assert o.valid?
      end
    end
  end

  def test_validates_associated_many
    Topic.validates_associated( :replies )
    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    t.replies << [r = Reply.new("title" => "A reply"), r2 = Reply.new("title" => "Another reply", "content" => "non-empty"), r3 = Reply.new("title" => "Yet another reply"), r4 = Reply.new("title" => "The last reply", "content" => "non-empty")]
    assert !t.valid?
    assert t.errors.on(:replies)
    assert_equal 1, r.errors.count  # make sure all associated objects have been validated
    assert_equal 0, r2.errors.count
    assert_equal 1, r3.errors.count
    assert_equal 0, r4.errors.count
    r.content = r3.content = "non-empty"
    assert t.valid?
  end

  def test_validates_associated_one
    repair_validations(Reply) do
      Reply.validates_associated( :topic )
      Topic.validates_presence_of( :content )
      r = Reply.new("title" => "A reply", "content" => "with content!")
      r.topic = Topic.create("title" => "uhohuhoh")
      assert !r.valid?
      assert r.errors.on(:topic)
      r.topic.content = "non-empty"
      assert r.valid?
    end
  end

  def test_validate_block
    Topic.validate { |topic| topic.errors.add("title", "will never be valid") }
    t = Topic.create("title" => "Title", "content" => "whatever")
    assert !t.valid?
    assert t.errors.on(:title)
    assert_equal "will never be valid", t.errors["title"]
  end

  def test_invalid_validator
    Topic.validate 3
    assert_raise(ArgumentError) { t = Topic.create }
  end

  def test_throw_away_typing
    d = Developer.new("name" => "David", "salary" => "100,000")
    assert !d.valid?
    assert_equal 100, d.salary
    assert_equal "100,000", d.salary_before_type_cast
  end

  def test_validates_acceptance_of_with_custom_error_using_quotes
    repair_validations(Developer) do
      Developer.validates_acceptance_of :salary, :message=> "This string contains 'single' and \"double\" quotes"
      d = Developer.new
      d.salary = "0"
      assert !d.valid?
      assert_equal "This string contains 'single' and \"double\" quotes", d.errors.on(:salary).last
    end
  end

  def test_validates_confirmation_of_with_custom_error_using_quotes
    repair_validations(Developer) do
      Developer.validates_confirmation_of :name, :message=> "confirm 'single' and \"double\" quotes"
      d = Developer.new
      d.name = "John"
      d.name_confirmation = "Johnny"
      assert !d.valid?
      assert_equal "confirm 'single' and \"double\" quotes", d.errors.on(:name)
    end
  end

  def test_validates_format_of_with_custom_error_using_quotes
    repair_validations(Developer) do
      Developer.validates_format_of :name, :with => /^(A-Z*)$/, :message=> "format 'single' and \"double\" quotes"
      d = Developer.new
      d.name = d.name_confirmation = "John 32"
      assert !d.valid?
      assert_equal "format 'single' and \"double\" quotes", d.errors.on(:name)
    end
  end

  def test_validates_inclusion_of_with_custom_error_using_quotes
    repair_validations(Developer) do
      Developer.validates_inclusion_of :salary, :in => 1000..80000, :message=> "This string contains 'single' and \"double\" quotes"
      d = Developer.new
      d.salary = "90,000"
      assert !d.valid?
      assert_equal "This string contains 'single' and \"double\" quotes", d.errors.on(:salary).last
    end
  end

  def test_validates_length_of_with_custom_too_long_using_quotes
    repair_validations(Developer) do
      Developer.validates_length_of :name, :maximum => 4, :too_long=> "This string contains 'single' and \"double\" quotes"
      d = Developer.new
      d.name = "Jeffrey"
      assert !d.valid?
      assert_equal "This string contains 'single' and \"double\" quotes", d.errors.on(:name)
    end
  end

  def test_validates_length_of_with_custom_too_short_using_quotes
    repair_validations(Developer) do
      Developer.validates_length_of :name, :minimum => 4, :too_short=> "This string contains 'single' and \"double\" quotes"
      d = Developer.new
      d.name = "Joe"
      assert !d.valid?
      assert_equal "This string contains 'single' and \"double\" quotes", d.errors.on(:name)
    end
  end

  def test_validates_length_of_with_custom_message_using_quotes
    repair_validations(Developer) do
      Developer.validates_length_of :name, :minimum => 4, :message=> "This string contains 'single' and \"double\" quotes"
      d = Developer.new
      d.name = "Joe"
      assert !d.valid?
      assert_equal "This string contains 'single' and \"double\" quotes", d.errors.on(:name)
    end
  end

  def test_validates_presence_of_with_custom_message_using_quotes
    repair_validations(Developer) do
      Developer.validates_presence_of :non_existent, :message=> "This string contains 'single' and \"double\" quotes"
      d = Developer.new
      d.name = "Joe"
      assert !d.valid?
      assert_equal "This string contains 'single' and \"double\" quotes", d.errors.on(:non_existent)
    end
  end

  def test_validates_uniqueness_of_with_custom_message_using_quotes
    repair_validations(Developer) do
      Developer.validates_uniqueness_of :name, :message=> "This string contains 'single' and \"double\" quotes"
      d = Developer.new
      d.name = "David"
      assert !d.valid?
      assert_equal "This string contains 'single' and \"double\" quotes", d.errors.on(:name)
    end
  end

  def test_validates_associated_with_custom_message_using_quotes
    repair_validations(Reply) do
      Reply.validates_associated :topic, :message=> "This string contains 'single' and \"double\" quotes"
      Topic.validates_presence_of :content
      r = Reply.create("title" => "A reply", "content" => "with content!")
      r.topic = Topic.create("title" => "uhohuhoh")
      assert !r.valid?
      assert_equal "This string contains 'single' and \"double\" quotes", r.errors.on(:topic)
    end
  end

  def test_if_validation_using_method_true
    # When the method returns true
    Topic.validates_length_of( :title, :maximum=>5, :too_long=>"hoo {{count}}", :if => :condition_is_true )
    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    assert !t.valid?
    assert t.errors.on(:title)
    assert_equal "hoo 5", t.errors["title"]
  end

  def test_unless_validation_using_method_true
    # When the method returns true
    Topic.validates_length_of( :title, :maximum=>5, :too_long=>"hoo {{count}}", :unless => :condition_is_true )
    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    assert t.valid?
    assert !t.errors.on(:title)
  end

  def test_if_validation_using_method_false
    # When the method returns false
    Topic.validates_length_of( :title, :maximum=>5, :too_long=>"hoo {{count}}", :if => :condition_is_true_but_its_not )
    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    assert t.valid?
    assert !t.errors.on(:title)
  end

  def test_unless_validation_using_method_false
    # When the method returns false
    Topic.validates_length_of( :title, :maximum=>5, :too_long=>"hoo {{count}}", :unless => :condition_is_true_but_its_not )
    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    assert !t.valid?
    assert t.errors.on(:title)
    assert_equal "hoo 5", t.errors["title"]
  end

  def test_if_validation_using_string_true
    # When the evaluated string returns true
    Topic.validates_length_of( :title, :maximum=>5, :too_long=>"hoo {{count}}", :if => "a = 1; a == 1" )
    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    assert !t.valid?
    assert t.errors.on(:title)
    assert_equal "hoo 5", t.errors["title"]
  end

  def test_unless_validation_using_string_true
    # When the evaluated string returns true
    Topic.validates_length_of( :title, :maximum=>5, :too_long=>"hoo {{count}}", :unless => "a = 1; a == 1" )
    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    assert t.valid?
    assert !t.errors.on(:title)
  end

  def test_if_validation_using_string_false
    # When the evaluated string returns false
    Topic.validates_length_of( :title, :maximum=>5, :too_long=>"hoo {{count}}", :if => "false")
    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    assert t.valid?
    assert !t.errors.on(:title)
  end

  def test_unless_validation_using_string_false
    # When the evaluated string returns false
    Topic.validates_length_of( :title, :maximum=>5, :too_long=>"hoo {{count}}", :unless => "false")
    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    assert !t.valid?
    assert t.errors.on(:title)
    assert_equal "hoo 5", t.errors["title"]
  end

  def test_if_validation_using_block_true
    # When the block returns true
    Topic.validates_length_of( :title, :maximum=>5, :too_long=>"hoo {{count}}",
      :if => Proc.new { |r| r.content.size > 4 } )
    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    assert !t.valid?
    assert t.errors.on(:title)
    assert_equal "hoo 5", t.errors["title"]
  end

  def test_unless_validation_using_block_true
    # When the block returns true
    Topic.validates_length_of( :title, :maximum=>5, :too_long=>"hoo {{count}}",
      :unless => Proc.new { |r| r.content.size > 4 } )
    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    assert t.valid?
    assert !t.errors.on(:title)
  end

  def test_if_validation_using_block_false
    # When the block returns false
    Topic.validates_length_of( :title, :maximum=>5, :too_long=>"hoo {{count}}",
      :if => Proc.new { |r| r.title != "uhohuhoh"} )
    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    assert t.valid?
    assert !t.errors.on(:title)
  end

  def test_unless_validation_using_block_false
    # When the block returns false
    Topic.validates_length_of( :title, :maximum=>5, :too_long=>"hoo {{count}}",
      :unless => Proc.new { |r| r.title != "uhohuhoh"} )
    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    assert !t.valid?
    assert t.errors.on(:title)
    assert_equal "hoo 5", t.errors["title"]
  end

  def test_validates_associated_missing
    repair_validations(Reply) do
      Reply.validates_presence_of(:topic)
      r = Reply.create("title" => "A reply", "content" => "with content!")
      assert !r.valid?
      assert r.errors.on(:topic)

      r.topic = Topic.find :first
      assert r.valid?
    end
  end

  def test_errors_to_xml
    r = Reply.new :title => "Wrong Create"
    assert !r.valid?
    xml = r.errors.to_xml(:skip_instruct => true)
    assert_equal "<errors>", xml.first(8)
    assert xml.include?("<error>Title is Wrong Create</error>")
    assert xml.include?("<error>Content Empty</error>")
  end

  def test_validation_order
    Topic.validates_presence_of :title, :author_name
    Topic.validate {|topic| topic.errors.add('author_email_address', 'will never be valid')}
    Topic.validates_length_of :title, :content, :minimum => 2

    t = Topic.new :title => ''
    t.valid?
    e = t.errors.instance_variable_get '@errors'
    assert_equal 'title', key = e.keys.first
    assert_equal "can't be blank", t.errors.on(key).first
    assert_equal 'is too short (minimum is 2 characters)', t.errors.on(key).second
    assert_equal 'author_name', key = e.keys.second
    assert_equal "can't be blank", t.errors.on(key)
    assert_equal 'author_email_address', key = e.keys.third
    assert_equal 'will never be valid', t.errors.on(key)
    assert_equal 'content', key = e.keys.fourth
    assert_equal 'is too short (minimum is 2 characters)', t.errors.on(key)
  end

  def test_invalid_should_be_the_opposite_of_valid
    Topic.validates_presence_of :title

    t = Topic.new
    assert t.invalid?
    assert t.errors.invalid?(:title)

    t.title = 'Things are going to change'
    assert !t.invalid?
  end

  # previous implementation of validates_presence_of eval'd the
  # string with the wrong binding, this regression test is to
  # ensure that it works correctly
  def test_validation_with_if_as_string
    Topic.validates_presence_of(:title)
    Topic.validates_presence_of(:author_name, :if => "title.to_s.match('important')")

    t = Topic.new
    assert !t.valid?, "A topic without a title should not be valid"
    assert !t.errors.invalid?("author_name"), "A topic without an 'important' title should not require an author"

    t.title = "Just a title"
    assert t.valid?, "A topic with a basic title should be valid"

    t.title = "A very important title"
    assert !t.valid?, "A topic with an important title, but without an author, should not be valid"
    assert t.errors.invalid?("author_name"), "A topic with an 'important' title should require an author"

    t.author_name = "Hubert J. Farnsworth"
    assert t.valid?, "A topic with an important title and author should be valid"
  end
end


class ValidatesNumericalityTest < ActiveRecord::TestCase
  NIL = [nil]
  BLANK = ["", " ", " \t \r \n"]
  BIGDECIMAL_STRINGS = %w(12345678901234567890.1234567890) # 30 significent digits
  FLOAT_STRINGS = %w(0.0 +0.0 -0.0 10.0 10.5 -10.5 -0.0001 -090.1 90.1e1 -90.1e5 -90.1e-5 90e-5)
  INTEGER_STRINGS = %w(0 +0 -0 10 +10 -10 0090 -090)
  FLOATS = [0.0, 10.0, 10.5, -10.5, -0.0001] + FLOAT_STRINGS
  INTEGERS = [0, 10, -10] + INTEGER_STRINGS
  BIGDECIMAL = BIGDECIMAL_STRINGS.collect! { |bd| BigDecimal.new(bd) }
  JUNK = ["not a number", "42 not a number", "0xdeadbeef", "00-1", "--3", "+-3", "+3-1", "-+019.0", "12.12.13.12", "123\nnot a number"]
  INFINITY = [1.0/0.0]

  repair_validations(Topic)

  def test_default_validates_numericality_of
    Topic.validates_numericality_of :approved

    invalid!(NIL + BLANK + JUNK)
    valid!(FLOATS + INTEGERS + BIGDECIMAL + INFINITY)
  end

  def test_validates_numericality_of_with_nil_allowed
    Topic.validates_numericality_of :approved, :allow_nil => true

    invalid!(JUNK)
    valid!(NIL + BLANK + FLOATS + INTEGERS + BIGDECIMAL + INFINITY)
  end

  def test_validates_numericality_of_with_integer_only
    Topic.validates_numericality_of :approved, :only_integer => true

    invalid!(NIL + BLANK + JUNK + FLOATS + BIGDECIMAL + INFINITY)
    valid!(INTEGERS)
  end

  def test_validates_numericality_of_with_integer_only_and_nil_allowed
    Topic.validates_numericality_of :approved, :only_integer => true, :allow_nil => true

    invalid!(JUNK + FLOATS + BIGDECIMAL + INFINITY)
    valid!(NIL + BLANK + INTEGERS)
  end

  def test_validates_numericality_with_greater_than
    Topic.validates_numericality_of :approved, :greater_than => 10

    invalid!([-10, 10], 'must be greater than 10')
    valid!([11])
  end

  def test_validates_numericality_with_greater_than_or_equal
    Topic.validates_numericality_of :approved, :greater_than_or_equal_to => 10

    invalid!([-9, 9], 'must be greater than or equal to 10')
    valid!([10])
  end

  def test_validates_numericality_with_equal_to
    Topic.validates_numericality_of :approved, :equal_to => 10

    invalid!([-10, 11] + INFINITY, 'must be equal to 10')
    valid!([10])
  end

  def test_validates_numericality_with_less_than
    Topic.validates_numericality_of :approved, :less_than => 10

    invalid!([10], 'must be less than 10')
    valid!([-9, 9])
  end

  def test_validates_numericality_with_less_than_or_equal_to
    Topic.validates_numericality_of :approved, :less_than_or_equal_to => 10

    invalid!([11], 'must be less than or equal to 10')
    valid!([-10, 10])
  end

  def test_validates_numericality_with_odd
    Topic.validates_numericality_of :approved, :odd => true

    invalid!([-2, 2], 'must be odd')
    valid!([-1, 1])
  end

  def test_validates_numericality_with_even
    Topic.validates_numericality_of :approved, :even => true

    invalid!([-1, 1], 'must be even')
    valid!([-2, 2])
  end

  def test_validates_numericality_with_greater_than_less_than_and_even
    Topic.validates_numericality_of :approved, :greater_than => 1, :less_than => 4, :even => true

    invalid!([1, 3, 4])
    valid!([2])
  end

  def test_validates_numericality_with_numeric_message
    Topic.validates_numericality_of :approved, :less_than => 4, :message => "smaller than {{count}}"
    topic = Topic.new("title" => "numeric test", "approved" => 10)

    assert !topic.valid?
    assert_equal "smaller than 4", topic.errors.on(:approved)

    Topic.validates_numericality_of :approved, :greater_than => 4, :message => "greater than {{count}}"
    topic = Topic.new("title" => "numeric test", "approved" => 1)

    assert !topic.valid?
    assert_equal "greater than 4", topic.errors.on(:approved)
  end

  private
    def invalid!(values, error=nil)
      with_each_topic_approved_value(values) do |topic, value|
        assert !topic.valid?, "#{value.inspect} not rejected as a number"
        assert topic.errors.on(:approved)
        assert_equal error, topic.errors.on(:approved) if error
      end
    end

    def valid!(values)
      with_each_topic_approved_value(values) do |topic, value|
        assert topic.valid?, "#{value.inspect} not accepted as a number"
      end
    end

    def with_each_topic_approved_value(values)
      topic = Topic.new("title" => "numeric test", "content" => "whatever")
      values.each do |value|
        topic.approved = value
        yield topic, value
      end
    end
end
