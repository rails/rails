# encoding: utf-8
require "cases/helper"
require 'models/topic'
require 'models/reply'
require 'models/warehouse_thing'
require 'models/guid'
require 'models/event'

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

class ReplyTitle; end

class ReplyWithTitleObject < Reply
  validates_uniqueness_of :content, :scope => :title

  def title; ReplyTitle.new; end
end

class UniquenessValidationTest < ActiveRecord::TestCase
  fixtures :topics, 'warehouse-things', :developers

  repair_validations(Topic, Reply)

  def test_validate_uniqueness
    Topic.validates_uniqueness_of(:title)

    t = Topic.new("title" => "I'm uniqué!")
    assert t.save, "Should save t as unique"

    t.content = "Remaining unique"
    assert t.save, "Should still save t as unique"

    t2 = Topic.new("title" => "I'm uniqué!")
    assert !t2.valid?, "Shouldn't be valid"
    assert !t2.save, "Shouldn't save t2 as unique"
    assert_equal ["has already been taken"], t2.errors[:title]

    t2.title = "Now Im really also unique"
    assert t2.save, "Should now save t2 as unique"
  end

  def test_validates_uniqueness_with_nil_value
    Topic.validates_uniqueness_of(:title)

    t = Topic.new("title" => nil)
    assert t.save, "Should save t as unique"

    t2 = Topic.new("title" => nil)
    assert !t2.valid?, "Shouldn't be valid"
    assert !t2.save, "Shouldn't save t2 as unique"
    assert_equal ["has already been taken"], t2.errors[:title]
  end

  def test_validates_uniqueness_with_validates
    Topic.validates :title, :uniqueness => true
    Topic.create!('title' => 'abc')

    t2 = Topic.new('title' => 'abc')
    assert !t2.valid?
    assert t2.errors[:title]
  end

  def test_validates_uniqueness_with_newline_chars
    Topic.validates_uniqueness_of(:title, :case_sensitive => false)

    t = Topic.new("title" => "new\nline")
    assert t.save, "Should save t as unique"
  end

  def test_validate_uniqueness_with_scope
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

  def test_validate_uniqueness_with_object_scope
    Reply.validates_uniqueness_of(:content, :scope => :topic)

    t = Topic.create("title" => "I'm unique!")

    r1 = t.replies.create "title" => "r1", "content" => "hello world"
    assert r1.valid?, "Saving r1"

    r2 = t.replies.create "title" => "r2", "content" => "hello world"
    assert !r2.valid?, "Saving r2 first time"
  end

  def test_validate_uniqueness_with_composed_attribute_scope
    r1 = ReplyWithTitleObject.create "title" => "r1", "content" => "hello world"
    assert r1.valid?, "Saving r1"

    r2 = ReplyWithTitleObject.create "title" => "r1", "content" => "hello world"
    assert !r2.valid?, "Saving r2 first time"
  end

  def test_validate_uniqueness_with_object_arg
    Reply.validates_uniqueness_of(:topic)

    t = Topic.create("title" => "I'm unique!")

    r1 = t.replies.create "title" => "r1", "content" => "hello world"
    assert r1.valid?, "Saving r1"

    r2 = t.replies.create "title" => "r2", "content" => "hello world"
    assert !r2.valid?, "Saving r2 first time"
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

  def test_validate_case_insensitive_uniqueness
    Topic.validates_uniqueness_of(:title, :parent_id, :case_sensitive => false, :allow_nil => true)

    t = Topic.new("title" => "I'm unique!", :parent_id => 2)
    assert t.save, "Should save t as unique"

    t.content = "Remaining unique"
    assert t.save, "Should still save t as unique"

    t2 = Topic.new("title" => "I'm UNIQUE!", :parent_id => 1)
    assert !t2.valid?, "Shouldn't be valid"
    assert !t2.save, "Shouldn't save t2 as unique"
    assert t2.errors[:title].any?
    assert t2.errors[:parent_id].any?
    assert_equal ["has already been taken"], t2.errors[:title]

    t2.title = "I'm truly UNIQUE!"
    assert !t2.valid?, "Shouldn't be valid"
    assert !t2.save, "Shouldn't save t2 as unique"
    assert t2.errors[:title].empty?
    assert t2.errors[:parent_id].any?

    t2.parent_id = 4
    assert t2.save, "Should now save t2 as unique"

    t2.parent_id = nil
    t2.title = nil
    assert t2.valid?, "should validate with nil"
    assert t2.save, "should save with nil"

    t_utf8 = Topic.new("title" => "Я тоже уникальный!")
    assert t_utf8.save, "Should save t_utf8 as unique"

    # If database hasn't UTF-8 character set, this test fails
    if Topic.all.merge!(:select => 'LOWER(title) AS title').find(t_utf8).title == "я тоже уникальный!"
      t2_utf8 = Topic.new("title" => "я тоже УНИКАЛЬНЫЙ!")
      assert !t2_utf8.valid?, "Shouldn't be valid"
      assert !t2_utf8.save, "Shouldn't save t2_utf8 as unique"
    end
  end

  def test_validate_case_sensitive_uniqueness_with_special_sql_like_chars
    Topic.validates_uniqueness_of(:title, :case_sensitive => true)

    t = Topic.new("title" => "I'm unique!")
    assert t.save, "Should save t as unique"

    t2 = Topic.new("title" => "I'm %")
    assert t2.save, "Should save t2 as unique"

    t3 = Topic.new("title" => "I'm uniqu_!")
    assert t3.save, "Should save t3 as unique"
  end

  def test_validate_case_insensitive_uniqueness_with_special_sql_like_chars
    Topic.validates_uniqueness_of(:title, :case_sensitive => false)

    t = Topic.new("title" => "I'm unique!")
    assert t.save, "Should save t as unique"

    t2 = Topic.new("title" => "I'm %")
    assert t2.save, "Should save t2 as unique"

    t3 = Topic.new("title" => "I'm uniqu_!")
    assert t3.save, "Should save t3 as unique"
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
    assert t2.errors[:title].empty?
    assert t2.errors[:parent_id].empty?
    assert_not_equal ["has already been taken"], t2.errors[:title]

    t3 = Topic.new("title" => "I'M uNiQUe!")
    assert t3.valid?, "Should be valid"
    assert t3.save, "Should save t2 as unique"
    assert t3.errors[:title].empty?
    assert t3.errors[:parent_id].empty?
    assert_not_equal ["has already been taken"], t3.errors[:title]
  end

  def test_validate_case_sensitive_uniqueness_with_attribute_passed_as_integer
    Topic.validates_uniqueness_of(:title, :case_sensitve => true)
    Topic.create!('title' => 101)

    t2 = Topic.new('title' => 101)
    assert !t2.valid?
    assert t2.errors[:title]
  end

  def test_validate_uniqueness_with_non_standard_table_names
    i1 = WarehouseThing.create(:value => 1000)
    assert !i1.valid?, "i1 should not be valid"
    assert i1.errors[:value].any?, "Should not be empty"
  end

  def test_validates_uniqueness_inside_scoping
    Topic.validates_uniqueness_of(:title)

    Topic.where(:author_name => "David").scoping do
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
    # Event.title is limited to 5 characters
    e1 = Event.create(:title => "一二三四五")
    assert e1.valid?, "Could not create an event with a unique, 5 character title"
    e2 = Event.create(:title => "一二三四五六七八")
    assert !e2.valid?, "Created an event whose title, with limit taken into account, is not unique"
  end

  def test_validate_straight_inheritance_uniqueness
    w1 = IneptWizard.create(:name => "Rincewind", :city => "Ankh-Morpork")
    assert w1.valid?, "Saving w1"

    # Should use validation from base class (which is abstract)
    w2 = IneptWizard.new(:name => "Rincewind", :city => "Quirm")
    assert !w2.valid?, "w2 shouldn't be valid"
    assert w2.errors[:name].any?, "Should have errors for name"
    assert_equal ["has already been taken"], w2.errors[:name], "Should have uniqueness message for name"

    w3 = Conjurer.new(:name => "Rincewind", :city => "Quirm")
    assert !w3.valid?, "w3 shouldn't be valid"
    assert w3.errors[:name].any?, "Should have errors for name"
    assert_equal ["has already been taken"], w3.errors[:name], "Should have uniqueness message for name"

    w4 = Conjurer.create(:name => "The Amazing Bonko", :city => "Quirm")
    assert w4.valid?, "Saving w4"

    w5 = Thaumaturgist.new(:name => "The Amazing Bonko", :city => "Lancre")
    assert !w5.valid?, "w5 shouldn't be valid"
    assert w5.errors[:name].any?, "Should have errors for name"
    assert_equal ["has already been taken"], w5.errors[:name], "Should have uniqueness message for name"

    w6 = Thaumaturgist.new(:name => "Mustrum Ridcully", :city => "Quirm")
    assert !w6.valid?, "w6 shouldn't be valid"
    assert w6.errors[:city].any?, "Should have errors for city"
    assert_equal ["has already been taken"], w6.errors[:city], "Should have uniqueness message for city"
  end
  
  def test_validate_uniqueness_with_conditions
    Topic.validates_uniqueness_of(:title, :conditions => Topic.where('approved = ?', true))
    Topic.create("title" => "I'm a topic", "approved" => true)
    Topic.create("title" => "I'm an unapproved topic", "approved" => false)
    
    t3 = Topic.new("title" => "I'm a topic", "approved" => true)
    assert !t3.valid?, "t3 shouldn't be valid"
    
    t4 = Topic.new("title" => "I'm an unapproved topic", "approved" => false)
    assert t4.valid?, "t4 should be valid"
  end
end
