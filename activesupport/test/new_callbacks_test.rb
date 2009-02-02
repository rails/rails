# require 'abstract_unit'
require 'test/unit'
$:.unshift "#{File.dirname(__FILE__)}/../lib"
require 'active_support'

class Record
  include ActiveSupport::Callbacks
  define_callbacks :save
end

class AroundPerson < Record
  attr_reader :history
  
  save_callback :before, :nope,           :if =>     :no
  save_callback :before, :nope,           :unless => :yes
  save_callback :after,  :tweedle
  save_callback :before, "tweedle_dee"
  save_callback :before, proc {|m| m.history << "yup" }
  save_callback :before, :nope,           :if =>     proc { false }
  save_callback :before, :nope,           :unless => proc { true }
  save_callback :before, :yup,            :if =>     proc { true }
  save_callback :before, :yup,            :unless => proc { false }
  save_callback :around, :tweedle_dum
  save_callback :around, :w0tyes,         :if =>     :yes
  save_callback :around, :w0tno,          :if =>     :no
  save_callback :around, :tweedle_deedle
  
  def no; false; end
  def yes; true; end
  
  def nope
    @history << "boom"
  end
  
  def yup
    @history << "yup"
  end
  
  def w0tyes
    @history << "w0tyes before"
    yield
    @history << "w0tyes after"
  end
  
  def w0tno
    @history << "boom"
    yield
  end
  
  def tweedle_dee
    @history << "tweedle dee"
  end
  
  def tweedle_dum
    @history << "tweedle dum pre"
    yield
    @history << "tweedle dum post"
  end
  
  def tweedle
    @history << "tweedle"
  end
  
  def tweedle_deedle
    @history << "tweedle deedle pre"
    yield
    @history << "tweedle deedle post"
  end
  
  def initialize
    @history = []
  end
  
  def save
    _run_save_callbacks do
      @history << "running"
    end
  end
end

class Foo
  include ActiveSupport::Callbacks
  define_callbacks :save
end

class Bar < Foo
  save_callback(:before) {|s| puts "Before" }
end

class Baz < Bar
  save_callback(:after) {|s| puts "After"}
end

class Bat < Baz
  def inside
    _run_save_callbacks do
      puts "Inside"
    end
  end
end

Bat.new.inside

# class AroundCallbacksTest < Test::Unit::TestCase
#   def test_save_around
#     around = AroundPerson.new
#     around.save
#     assert_equal [
#       "tweedle dee",
#       "yup", "yup", "yup",
#       "tweedle dum pre",
#       "w0tyes before",
#       "tweedle deedle pre",
#       "running",
#       "tweedle deedle post",
#       "w0tyes after",
#       "tweedle dum post",
#       "tweedle"
#     ], around.history
#   end
# end