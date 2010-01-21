# encoding: utf-8

module Tests
  module Api
    module Interpolation
      def interpolate(*args)
        options = args.last.is_a?(Hash) ? args.pop : {}
        key = args.pop
        I18n.backend.translate('en', key, options)
      end

      define_method "test interpolation: given no values it does not alter the string" do
        assert_equal 'Hi {{name}}!', interpolate(:default => 'Hi {{name}}!')
      end

      define_method "test interpolation: given values it interpolates them into the string" do
        assert_equal 'Hi David!', interpolate(:default => 'Hi {{name}}!', :name => 'David')
      end

      define_method "test interpolation: given a nil value it still interpolates it into the string" do
        assert_equal 'Hi !', interpolate(:default => 'Hi {{name}}!', :name => nil)
      end

      define_method "test interpolation: given a lambda as a value it calls it if the string contains the key" do
        assert_equal 'Hi David!', interpolate(:default => 'Hi {{name}}!', :name => lambda { |*args| 'David' })
      end

      define_method "test interpolation: given a lambda as a value it does not call it if the string does not contain the key" do
        assert_nothing_raised { interpolate(:default => 'Hi!', :name => lambda { |*args| raise 'fail' }) }
      end

      define_method "test interpolation: given values but missing a key it raises I18n::MissingInterpolationArgument" do
        assert_raises(I18n::MissingInterpolationArgument) do
          interpolate(:default => '{{foo}}', :bar => 'bar')
        end
      end

      define_method "test interpolation: it does not raise I18n::MissingInterpolationArgument for escaped variables" do
        assert_nothing_raised(I18n::MissingInterpolationArgument) do
          assert_equal 'Barr {{foo}}', interpolate(:default => '{{bar}} \{{foo}}', :bar => 'Barr')
        end
      end

      define_method "test interpolation: it does not change the original, stored translation string" do
        I18n.backend.store_translations(:en, :interpolate => 'Hi {{name}}!')
        assert_equal 'Hi David!', interpolate(:interpolate, :name => 'David')
        assert_equal 'Hi Yehuda!', interpolate(:interpolate, :name => 'Yehuda')
      end

      define_method "test interpolation: works with Ruby 1.9 syntax" do
        assert_equal 'Hi David!', interpolate(:default => 'Hi %{name}!', :name => 'David')
      end

      define_method "test interpolation: given the translation is in utf-8 it still works" do
        assert_equal 'Häi David!', interpolate(:default => 'Häi {{name}}!', :name => 'David')
      end

      define_method "test interpolation: given the value is in utf-8 it still works" do
        assert_equal 'Hi ゆきひろ!', interpolate(:default => 'Hi {{name}}!', :name => 'ゆきひろ')
      end

      define_method "test interpolation: given the translation and the value are in utf-8 it still works" do
        assert_equal 'こんにちは、ゆきひろさん!', interpolate(:default => 'こんにちは、{{name}}さん!', :name => 'ゆきひろ')
      end

      if Kernel.const_defined?(:Encoding)
        define_method "test interpolation: given a euc-jp translation and a utf-8 value it raises Encoding::CompatibilityError" do
          assert_raises(Encoding::CompatibilityError) do
            interpolate(:default => euc_jp('こんにちは、{{name}}さん!'), :name => 'ゆきひろ')
          end
        end
        
        # define_method "test interpolation: given a utf-8 translation and a euc-jp value it returns a translation in euc-jp" do
        #   assert_equal euc_jp('Hi ゆきひろ!'), interpolate(:default => 'Hi {{name}}!', :name => euc_jp('ゆきひろ'))
        # end
        # 
        # TODO should better explain how this relates to the test above with the simpler utf-8 default string
        define_method "test interpolation: given a utf-8 translation and a euc-jp value it raises Encoding::CompatibilityError" do
          assert_raises(Encoding::CompatibilityError) do
            interpolate(:default => 'こんにちは、{{name}}さん!', :name => euc_jp('ゆきひろ'))
          end
        end
      end

      define_method "test interpolation: given a translations containing a reserved key it raises I18n::ReservedInterpolationKey" do
        assert_raises(I18n::ReservedInterpolationKey) { interpolate(:default => '{{default}}',   :foo => :bar) }
        assert_raises(I18n::ReservedInterpolationKey) { interpolate(:default => '{{scope}}',     :foo => :bar) }
        assert_raises(I18n::ReservedInterpolationKey) { interpolate(:default => '{{separator}}', :foo => :bar) }
      end
    end
  end
end
