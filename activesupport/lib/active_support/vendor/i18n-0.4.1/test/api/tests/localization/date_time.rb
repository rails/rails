# encoding: utf-8

module Tests
  module Api
    module Localization
      module DateTime
        def setup
          super
          setup_datetime_translations
          @datetime = ::DateTime.new(2008, 3, 1, 6)
          @other_datetime = ::DateTime.new(2008, 3, 1, 18)
        end

        define_method "test localize DateTime: given the short format it uses it" do
          # TODO should be Mrz, shouldn't it?
          assert_equal '01. Mar 06:00', I18n.l(@datetime, :format => :short, :locale => :de)
        end

        define_method "test localize DateTime: given the long format it uses it" do
          assert_equal '01. März 2008 06:00', I18n.l(@datetime, :format => :long, :locale => :de)
        end

        define_method "test localize DateTime: given the default format it uses it" do
          # TODO should be Mrz, shouldn't it?
          assert_equal 'Sa, 01. Mar 2008 06:00:00 +0000', I18n.l(@datetime, :format => :default, :locale => :de)
        end

        define_method "test localize DateTime: given a day name format it returns the correct day name" do
          assert_equal 'Samstag', I18n.l(@datetime, :format => '%A', :locale => :de)
        end

        define_method "test localize DateTime: given an abbreviated day name format it returns the correct abbreviated day name" do
          assert_equal 'Sa', I18n.l(@datetime, :format => '%a', :locale => :de)
        end

        define_method "test localize DateTime: given a month name format it returns the correct month name" do
          assert_equal 'März', I18n.l(@datetime, :format => '%B', :locale => :de)
        end

        define_method "test localize DateTime: given an abbreviated month name format it returns the correct abbreviated month name" do
          # TODO should be Mrz, shouldn't it?
          assert_equal 'Mar', I18n.l(@datetime, :format => '%b', :locale => :de)
        end

        define_method "test localize DateTime: given a meridian indicator format it returns the correct meridian indicator" do
          assert_equal 'am', I18n.l(@datetime, :format => '%p', :locale => :de)
          assert_equal 'pm', I18n.l(@other_datetime, :format => '%p', :locale => :de)
        end

        define_method "test localize DateTime: given an unknown format it does not fail" do
          assert_nothing_raised { I18n.l(@datetime, :format => '%x') }
        end

        define_method "test localize DateTime: given a format is missing it raises I18n::MissingTranslationData" do
          assert_raise(I18n::MissingTranslationData) { I18n.l(@datetime, :format => :missing) }
        end

        protected

          def setup_datetime_translations
            # time translations might have been set up in Tests::Api::Localization::Time
            store_translations :de, {
              :time => {
                :formats => {
                  :default => "%a, %d. %b %Y %H:%M:%S %z",
                  :short => "%d. %b %H:%M",
                  :long => "%d. %B %Y %H:%M"
                },
                :am => 'am',
                :pm => 'pm'
              }
            }
          end
      end
    end
  end
end
