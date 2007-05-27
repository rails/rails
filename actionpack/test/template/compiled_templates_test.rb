require "#{File.dirname(__FILE__)}/../abstract_unit"
require 'action_view/helpers/date_helper'
require 'action_view/compiled_templates'

class CompiledTemplateTests < Test::Unit::TestCase
  def setup
    @ct = ActionView::CompiledTemplates.new
    @v = Class.new
    @v.send :include, @ct
    @a = './test_compile_template_a.rhtml'
    @b = './test_compile_template_b.rhtml'
    @s = './test_compile_template_link.rhtml'
  end
  def teardown
    [@a, @b, @s].each do |f|
      FileUtils.rm(f) if File.exist?(f) || File.symlink?(f)
    end
  end
  attr_reader :ct, :v

  def test_name_allocation
    hi_world = ct.method_names['hi world']
    hi_sexy = ct.method_names['hi sexy']
    wish_upon_a_star = ct.method_names['I love seeing decent error messages']

    assert_equal hi_world, ct.method_names['hi world']
    assert_equal hi_sexy, ct.method_names['hi sexy']
    assert_equal wish_upon_a_star, ct.method_names['I love seeing decent error messages']
    assert_equal 3, [hi_world, hi_sexy, wish_upon_a_star].uniq.length
  end

  def test_wrap_source
    assert_equal(
      "def aliased_assignment(value)\nself.value = value\nend",
      @ct.wrap_source(:aliased_assignment, [:value], 'self.value = value')
    )

    assert_equal(
      "def simple()\nnil\nend",
      @ct.wrap_source(:simple, [], 'nil')
    )
  end

  def test_compile_source_single_method
    selector = ct.compile_source('doubling method', [:a], 'a + a')
    assert_equal 2, @v.new.send(selector, 1)
    assert_equal 4, @v.new.send(selector, 2)
    assert_equal -4, @v.new.send(selector, -2)
    assert_equal 0, @v.new.send(selector, 0)
    selector
  end

  def test_compile_source_two_method
    sel1 = test_compile_source_single_method # compile the method in the other test
    sel2 = ct.compile_source('doubling method', [:a, :b], 'a + b + a + b')
    assert_not_equal sel1, sel2

    assert_equal 2, @v.new.send(sel1, 1)
    assert_equal 4, @v.new.send(sel1, 2)

    assert_equal 6, @v.new.send(sel2, 1, 2)
    assert_equal 32, @v.new.send(sel2, 15, 1)
  end

  def test_mtime
    t1 = Time.now
    test_compile_source_single_method
    assert (t1..Time.now).include?(ct.mtime('doubling method', [:a]))
  end

  def test_compile_time
    t = Time.now
    sleep 1
    File.open(@a, "w"){|f| f.puts @a}
    File.open(@b, "w"){|f| f.puts @b}
    # windows doesn't support symlinks (even under cygwin)
    windows = (RUBY_PLATFORM =~ /win32/)
    `ln -s #{@a} #{@s}` unless windows

    v = ActionView::Base.new
    v.base_path = '.'
    v.cache_template_loading = false

    # private methods template_changed_since? and compile_template?
    # should report true for all since they have not been compiled
    assert v.send(:template_changed_since?, @a, t)
    assert v.send(:template_changed_since?, @b, t)
    assert v.send(:template_changed_since?, @s, t) unless windows
    assert v.send(:compile_template?, nil, @a, {})
    assert v.send(:compile_template?, nil, @b, {})
    assert v.send(:compile_template?, nil, @s, {}) unless windows

    sleep 1
    v.compile_and_render_template(:rhtml, '', @a)
    v.compile_and_render_template(:rhtml, '', @b)
    v.compile_and_render_template(:rhtml, '', @s)
    a_n = v.method_names[@a]
    b_n = v.method_names[@b]
    s_n = v.method_names[@s] unless windows
    # all of the files have changed since last compile
    assert v.compile_time[a_n] > t
    assert v.compile_time[b_n] > t
    assert v.compile_time[s_n] > t unless windows

    sleep 1
    t = Time.now
    # private methods template_changed_since? and compile_template?
    # should report false for all since none have changed since compile
    assert !v.send(:template_changed_since?, @a, v.compile_time[a_n])
    assert !v.send(:template_changed_since?, @b, v.compile_time[b_n])
    assert !v.send(:template_changed_since?, @s, v.compile_time[s_n]) unless windows
    assert !v.send(:compile_template?, nil, @a, {})
    assert !v.send(:compile_template?, nil, @b, {})
    assert !v.send(:compile_template?, nil, @s, {}) unless windows
    v.compile_and_render_template(:rhtml, '', @a)
    v.compile_and_render_template(:rhtml, '', @b)
    v.compile_and_render_template(:rhtml, '', @s)  unless windows
    # none of the files have changed since last compile
    assert v.compile_time[a_n] < t
    assert v.compile_time[b_n] < t
    assert v.compile_time[s_n] < t  unless windows

    `rm #{@s}; ln -s #{@b} #{@s}` unless windows
    # private methods template_changed_since? and compile_template?
    # should report true for symlink since it has changed since compile
    assert !v.send(:template_changed_since?, @a, v.compile_time[a_n])
    assert !v.send(:template_changed_since?, @b, v.compile_time[b_n])
    assert v.send(:template_changed_since?, @s, v.compile_time[s_n]) unless windows
    assert !v.send(:compile_template?, nil, @a, {})
    assert !v.send(:compile_template?, nil, @b, {})
    assert v.send(:compile_template?, nil, @s, {}) unless windows
    v.compile_and_render_template(:rhtml, '', @a)
    v.compile_and_render_template(:rhtml, '', @b)
    v.compile_and_render_template(:rhtml, '', @s) unless windows
    # the symlink has changed since last compile
    assert v.compile_time[a_n] < t
    assert v.compile_time[b_n] < t
    assert v.compile_time[s_n] > t unless windows

    sleep 1
    FileUtils.touch @b
    # private methods template_changed_since? and compile_template?
    # should report true for symlink and file at end of symlink
    # since it has changed since last compile
    assert !v.send(:template_changed_since?, @a, v.compile_time[a_n])
    assert v.send(:template_changed_since?, @b, v.compile_time[b_n])
    assert v.send(:template_changed_since?, @s, v.compile_time[s_n]) unless windows
    assert !v.send(:compile_template?, nil, @a, {})
    assert v.send(:compile_template?, nil, @b, {})
    assert v.send(:compile_template?, nil, @s, {}) unless windows

    t = Time.now
    sleep 1
    v.compile_and_render_template(:rhtml, '', @a)
    v.compile_and_render_template(:rhtml, '', @b)
    v.compile_and_render_template(:rhtml, '', @s) unless windows
    # the file at the end of the symlink has changed since last compile
    # both the symlink and the file at the end of it should be recompiled
    assert v.compile_time[a_n] < t
    assert v.compile_time[b_n] > t
    assert v.compile_time[s_n] > t  unless windows
  end
end

module ActionView
  class Base
    def compile_time
      @@compile_time
    end
    def method_names
      @@method_names
    end
  end
end
