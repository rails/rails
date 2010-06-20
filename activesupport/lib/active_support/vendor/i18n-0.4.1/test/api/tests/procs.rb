# encoding: utf-8

module Tests
  module Api
    module Procs
      define_method "test lookup: given a translation is a proc it calls the proc with the key and interpolation values" do
        if can_store_procs?
          store_translations(:a_lambda => lambda { |*args| args.inspect })
          assert_equal '[:a_lambda, {:foo=>"foo"}]', I18n.t(:a_lambda, :foo => 'foo')
        end
      end

      define_method "test defaults: given a default is a Proc it calls it with the key and interpolation values" do
        proc = lambda { |*args| args.inspect }
        assert_equal '[nil, {:foo=>"foo"}]', I18n.t(nil, :default => proc, :foo => 'foo')
      end

      define_method "test defaults: given a default is a key that resolves to a Proc it calls it with the key and interpolation values" do
        if can_store_procs?
          store_translations(:a_lambda => lambda { |*args| args.inspect })
          assert_equal '[:a_lambda, {:foo=>"foo"}]', I18n.t(nil, :default => :a_lambda, :foo => 'foo')
          assert_equal '[:a_lambda, {:foo=>"foo"}]', I18n.t(nil, :default => [nil, :a_lambda], :foo => 'foo')
        end
      end

      define_method "test interpolation: given an interpolation value is a lambda it calls it with key and values before interpolating it" do
        proc = lambda { |*args| args.inspect }
        assert_match %r(\[\{:foo=>#<Proc.*>\}\]), I18n.t(nil, :default => '%{foo}', :foo => proc)
      end

      define_method "test interpolation: given a key resolves to a Proc that returns a string then interpolation still works" do
        proc = lambda { |*args| "%{foo}: " + args.inspect }
        assert_equal 'foo: [nil, {:foo=>"foo"}]', I18n.t(nil, :default => proc, :foo => 'foo')
      end

      define_method "test pluralization: given a key resolves to a Proc that returns valid data then pluralization still works" do
        proc = lambda { |*args| { :zero => 'zero', :one => 'one', :other => 'other' } }
        assert_equal 'zero',  I18n.t(:default => proc, :count => 0)
        assert_equal 'one',   I18n.t(:default => proc, :count => 1)
        assert_equal 'other', I18n.t(:default => proc, :count => 2)
      end

      define_method "test lookup: given the option :resolve => false was passed it does not resolve proc translations" do
        if can_store_procs?
          store_translations(:a_lambda => lambda { |*args| args.inspect })
          assert_equal Proc, I18n.t(:a_lambda, :resolve => false).class
        end
      end

      define_method "test lookup: given the option :resolve => false was passed it does not resolve proc default" do
        assert_equal Proc, I18n.t(nil, :default => lambda { |*args| args.inspect }, :resolve => false).class
      end
    end
  end
end