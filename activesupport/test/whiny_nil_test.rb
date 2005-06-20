require 'test/unit'


## mock to enable testing without activerecord
module ActiveRecord
  class Base
    def save!
    end
  end
end

require 'active_support/whiny_nil'



class WhinyNilTest < Test::Unit::TestCase
  def test_unchanged
    begin
      nil.method_thats_not_in_whiners
    rescue NoMethodError => nme
      assert_match(/nil:NilClass/, nme.message)
    end
  end
  
  def test_active_record
    begin
      nil.save!
    rescue NoMethodError => nme
      assert(!(nme.message =~ /nil:NilClass/))
    end
  end
  
  def test_array
    begin
      nil.each
    rescue NoMethodError => nme
      assert(!(nme.message =~ /nil:NilClass/))
    end
  end
end