# encoding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../../../test_helper')

# thanks to Masao's String extensions these should work the same in
# Ruby 1.8 (patched) and Ruby 1.9 (native)
# some tests taken from Masao's tests
# http://github.com/mutoh/gettext/blob/edbbe1fa8238fa12c7f26f2418403015f0270e47/test/test_string.rb

class I18nCoreExtStringInterpolationTest < Test::Unit::TestCase
  define_method "test: String interpolates a single argument" do
    assert_equal "Masao", "%s" % "Masao"
  end

  define_method "test: String interpolates an array argument" do
    assert_equal "1 message", "%d %s" % [1, 'message']
  end

  define_method "test: String interpolates a hash argument w/ named placeholders" do
    assert_equal "Masao Mutoh", "%{first} %{last}" % { :first => 'Masao', :last => 'Mutoh' }
  end

  define_method "test: String interpolates a hash argument w/ named placeholders (reverse order)" do
    assert_equal "Mutoh, Masao", "%{last}, %{first}" % { :first => 'Masao', :last => 'Mutoh' }
  end

  define_method "test: String interpolates named placeholders with sprintf syntax" do
    assert_equal "10, 43.4", "%<integer>d, %<float>.1f" % {:integer => 10, :float => 43.4}
  end

  define_method "test: String interpolates named placeholders with sprintf syntax, does not recurse" do
    assert_equal "%<not_translated>s", "%{msg}" % { :msg => '%<not_translated>s', :not_translated => 'should not happen' }
  end

  define_method "test: String interpolation does not replace anything when no placeholders are given" do
    assert_equal("aaa", "aaa" % {:num => 1})
    assert_equal("bbb", "bbb" % [1])
  end

  define_method "test: String interpolation sprintf behaviour equals Ruby 1.9 behaviour" do
    assert_equal("1", "%<num>d" % {:num => 1})
    assert_equal("0b1", "%<num>#b" % {:num => 1})
    assert_equal("foo", "%<msg>s" % {:msg => "foo"})
    assert_equal("1.000000", "%<num>f" % {:num => 1.0})
    assert_equal("  1", "%<num>3.0f" % {:num => 1.0})
    assert_equal("100.00", "%<num>2.2f" % {:num => 100.0})
    assert_equal("0x64", "%<num>#x" % {:num => 100.0})
    assert_raise(ArgumentError) { "%<num>,d" % {:num => 100} }
    assert_raise(ArgumentError) { "%<num>/d" % {:num => 100} }
  end

  define_method "test: String interpolation old-style sprintf still works" do
    assert_equal("foo 1.000000", "%s %f" % ["foo", 1.0])
  end

  define_method "test: String interpolation raises an ArgumentError when the string has extra placeholders (Array)" do
    assert_raises(ArgumentError) do # Ruby 1.9 msg: "too few arguments"
      "%s %s" % %w(Masao)
    end
  end

  define_method "test: String interpolation raises a KeyError when the string has extra placeholders (Hash)" do
    assert_raises(KeyError) do # Ruby 1.9 msg: "key not found"
      "%{first} %{last}" % { :first => 'Masao' }
    end
  end

  define_method "test: String interpolation does not raise when passed extra values (Array)" do
    assert_nothing_raised do
      assert_equal "Masao", "%s" % %w(Masao Mutoh)
    end
  end

  define_method "test: String interpolation does not raise when passed extra values (Hash)" do
    assert_nothing_raised do
      assert_equal "Masao Mutoh", "%{first} %{last}" % { :first => 'Masao', :last => 'Mutoh', :salutation => 'Mr.' }
    end
  end

  define_method "test: % acts as escape character in String interpolation" do
    assert_equal "%{first}", "%%{first}" % { :first => 'Masao' }
    assert_equal("% 1", "%% %<num>d" % {:num => 1.0})
    assert_equal("%{num} %<num>d", "%%{num} %%<num>d" % {:num => 1})
  end

  def test_sprintf_mix_unformatted_and_formatted_named_placeholders
    assert_equal("foo 1.000000", "%{name} %<num>f" % {:name => "foo", :num => 1.0})
  end
  
  def test_string_interpolation_raises_an_argument_error_when_mixing_named_and_unnamed_placeholders
    assert_raises(ArgumentError) { "%{name} %f" % [1.0] }
    assert_raises(ArgumentError) { "%{name} %f" % [1.0, 2.0] }
  end
end
