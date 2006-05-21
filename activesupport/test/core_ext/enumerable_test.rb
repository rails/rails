require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/active_support/core_ext/enumerable'

class EnumerableTests < Test::Unit::TestCase
  
  def test_group_by
    names = %w(marcel sam david jeremy)
    klass = Class.new
    klass.send(:attr_accessor, :name)
    objects = (1..50).inject([]) do |people,| 
      p = klass.new
      p.name = names.sort_by { rand }.first
      people << p
    end

    objects.group_by {|object| object.name}.each do |name, group|
      assert group.all? {|person| person.name == name}
    end
  end
end
