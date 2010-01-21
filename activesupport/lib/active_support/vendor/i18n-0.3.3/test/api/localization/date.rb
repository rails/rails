# encoding: utf-8

module Tests
  module Api
    module Localization
      module Date
        def setup
          super
          setup_date_translations
          @date = ::Date.new(2008, 3, 1)
        end
        
        define_method "test localize Date: given the short format it uses it" do
          # TODO should be Mrz, shouldn't it?
          assert_equal '01. Mar', I18n.l(@date, :format => :short, :locale => :de)
        end

        define_method "test localize Date: given the long format it uses it" do
          assert_equal '01. März 2008', I18n.l(@date, :format => :long, :locale => :de)
        end

        define_method "test localize Date: given the default format it uses it" do
          assert_equal '01.03.2008', I18n.l(@date, :format => :default, :locale => :de)
        end

        define_method "test localize Date: given a day name format it returns the correct day name" do
          assert_equal 'Samstag', I18n.l(@date, :format => '%A', :locale => :de)
        end

        define_method "test localize Date: given an abbreviated day name format it returns the correct abbreviated day name" do
          assert_equal 'Sa', I18n.l(@date, :format => '%a', :locale => :de)
        end

        define_method "test localize Date: given a month name format it returns the correct month name" do
          assert_equal 'März', I18n.l(@date, :format => '%B', :locale => :de)
        end

        define_method "test localize Date: given an abbreviated month name format it returns the correct abbreviated month name" do
          # TODO should be Mrz, shouldn't it?
          assert_equal 'Mar', I18n.l(@date, :format => '%b', :locale => :de)
        end

        define_method "test localize Date: given a format that resolves to a Proc it calls the Proc with the object" do
          # TODO should be Mrz, shouldn't it?
          assert_equal '[Sat, 01 Mar 2008, {}]', I18n.l(@date, :format => :proc, :locale => :de)
        end

        # TODO fails, but something along these lines probably should pass
        # define_method "test localize Date: given a format that resolves to a Proc it calls the Proc with the object and extra options" do
        #   assert_equal '[Sat Mar 01 06:00:00 UTC 2008, {:foo=>"foo"}]', I18n.l(@time, :format => :proc, :foo => 'foo', :locale => :de)
        # end

        define_method "test localize Date: given an unknown format it does not fail" do
          assert_nothing_raised { I18n.l(@date, :format => '%x') }
        end

        define_method "test localize Date: given nil it raises I18n::ArgumentError" do
          assert_raises(I18n::ArgumentError) { I18n.l(nil) }
        end

        define_method "test localize Date: given a plain Object it raises I18n::ArgumentError" do
          assert_raises(I18n::ArgumentError) { I18n.l(Object.new) }
        end
        
        define_method "test localize Date: it does not alter the format string" do
          assert_equal '01. Februar 2009', I18n.l(::Date.parse('2009-02-01'), :format => :long, :locale => :de)
          assert_equal '01. Oktober 2009', I18n.l(::Date.parse('2009-10-01'), :format => :long, :locale => :de)
        end

        protected
        
          def setup_date_translations
            store_translations :de, {
              :date => {
                :formats => {
                  :default => "%d.%m.%Y",
                  :short => "%d. %b",
                  :long => "%d. %B %Y",
                  :proc => lambda { |*args| args.inspect }
                },
                :day_names => %w(Sonntag Montag Dienstag Mittwoch Donnerstag Freitag Samstag),
                :abbr_day_names => %w(So Mo Di Mi Do Fr  Sa),
                :month_names => %w(Januar Februar März April Mai Juni Juli August September Oktober November Dezember).unshift(nil),
                :abbr_month_names => %w(Jan Feb Mar Apr Mai Jun Jul Aug Sep Okt Nov Dez).unshift(nil)
              }
            }
          end
      end
    end
  end
end
