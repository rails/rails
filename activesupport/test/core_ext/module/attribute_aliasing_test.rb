require File.dirname(__FILE__) + '/../../abstract_unit'

module AttributeAliasing
  class Content
    attr_accessor :title
  
    def title?
      !title.nil?
    end
  end

  class Email < Content
    alias_attribute :subject, :title
  end
end

class AttributeAliasingTest < Test::Unit::TestCase
  def test_attribute_alias
    e = AttributeAliasing::Email.new

    assert !e.subject?

    e.title = "Upgrade computer"
    assert_equal "Upgrade computer", e.subject
    assert e.subject?

    e.subject = "We got a long way to go"
    assert_equal "We got a long way to go", e.title
    assert e.title?
  end
end
