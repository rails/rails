# encoding: utf-8

module Tests
  module Api
    module Pluralization
      define_method "test pluralization: given 0 it returns the :zero translation if it is defined" do
        assert_equal 'zero', I18n.t(:default => { :zero => 'zero' }, :count => 0)
      end

      define_method "test pluralization: given 0 it returns the :other translation if :zero is not defined" do
        assert_equal 'bars', I18n.t(:default => { :other => 'bars' }, :count => 0)
      end

      define_method "test pluralization: given 1 it returns the singular translation" do
        assert_equal 'bar', I18n.t(:default => { :one => 'bar' }, :count => 1)
      end

      define_method "test pluralization: given 2 it returns the :other translation" do
        assert_equal 'bars', I18n.t(:default => { :other => 'bars' }, :count => 2)
      end

      define_method "test pluralization: given 3 it returns the :other translation" do
        assert_equal 'bars', I18n.t(:default => { :other => 'bars' }, :count => 3)
      end

      define_method "test pluralization: given nil it returns the whole entry" do
        assert_equal({ :one => 'bar' }, I18n.t(:default => { :one => 'bar' }, :count => nil))
      end

      define_method "test pluralization: given incomplete pluralization data it raises I18n::InvalidPluralizationData" do
        assert_raises(I18n::InvalidPluralizationData) { I18n.t(:default => { :one => 'bar' }, :count => 2) }
      end
    end
  end
end
