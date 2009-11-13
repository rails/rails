# Stub to enable testing without Active Record
module ActiveRecord
  class Base
    def save!
    end
  end
end

require 'abstract_unit'
require 'active_support/whiny_nil'

class WhinyNilTest < Test::Unit::TestCase
  def test_unchanged
    nil.method_thats_not_in_whiners
  rescue NoMethodError => nme
    assert(nme.message =~ /nil:NilClass/)
  end

  def test_active_record
    nil.save!
  rescue NoMethodError => nme
    assert(!(nme.message =~ /nil:NilClass/))
    assert_match(/nil\.save!/, nme.message)
  end

  def test_array
    nil.each
  rescue NoMethodError => nme
    assert(!(nme.message =~ /nil:NilClass/))
    assert_match(/nil\.each/, nme.message)
  end

  def test_id
    nil.id
  rescue RuntimeError => nme
    assert(!(nme.message =~ /nil:NilClass/))
  end

  def test_no_to_ary_coercion
    nil.to_ary
  rescue NoMethodError => nme
    assert(nme.message =~ /nil:NilClass/)
  end

  def test_no_to_str_coercion
    nil.to_str
  rescue NoMethodError => nme
    assert(nme.message =~ /nil:NilClass/)
  end
end
