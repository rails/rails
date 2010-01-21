# encoding: utf-8

module Tests
  module Api
    module Localization
      module Time
        def setup
          super
          setup_time_translations
          @time = ::Time.parse('2008-03-01 6:00 UTC')
          @other_time = ::Time.parse('2008-03-01 18:00 UTC')
        end
        
        define_method "test localize Time: given the short format it uses it" do
          # TODO should be Mrz, shouldn't it?
          assert_equal '01. Mar 06:00', I18n.l(@time, :format => :short, :locale => :de)
        end
        
        define_method "test localize Time: given the long format it uses it" do
          assert_equal '01. März 2008 06:00', I18n.l(@time, :format => :long, :locale => :de)
        end
        
        # TODO Seems to break on Windows because ENV['TZ'] is ignored. What's a better way to do this?
        # def test_localize_given_the_default_format_it_uses_it
        #   assert_equal 'Sa, 01. Mar 2008 06:00:00 +0000', I18n.l(@time, :format => :default, :locale => :de)
        # end
        
        define_method "test localize Time: given a day name format it returns the correct day name" do
          assert_equal 'Samstag', I18n.l(@time, :format => '%A', :locale => :de)
        end
        
        define_method "test localize Time: given an abbreviated day name format it returns the correct abbreviated day name" do
          assert_equal 'Sa', I18n.l(@time, :format => '%a', :locale => :de)
        end
        
        define_method "test localize Time: given a month name format it returns the correct month name" do
          assert_equal 'März', I18n.l(@time, :format => '%B', :locale => :de)
        end
        
        define_method "test localize Time: given an abbreviated month name format it returns the correct abbreviated month name" do
          # TODO should be Mrz, shouldn't it?
          assert_equal 'Mar', I18n.l(@time, :format => '%b', :locale => :de)
        end
        
        define_method "test localize Time: given a meridian indicator format it returns the correct meridian indicator" do
          assert_equal 'am', I18n.l(@time, :format => '%p', :locale => :de)
          assert_equal 'pm', I18n.l(@other_time, :format => '%p', :locale => :de)
        end

        define_method "test localize Time: given a format that resolves to a Proc it calls the Proc with the object" do
          if can_store_procs?
            assert_equal '[Sat, 01 Mar 2008 06:00:00 +0000, {}]', I18n.l(@datetime, :format => :proc, :locale => :de)
          end
        end
        
        # TODO fails, but something along these lines probably should pass
        # define_method "test localize Time: given a format that resolves to a Proc it calls the Proc with the object and extra options" do
        #   assert_equal '[Sat Mar 01 06:00:00 UTC 2008, {:foo=>"foo"}]', I18n.l(@time, :format => :proc, :foo => 'foo', :locale => :de)
        # end
        
        define_method "test localize Time: given an unknown format it does not fail" do
          assert_nothing_raised { I18n.l(@time, :format => '%x') }
        end
        
        protected
        
          def setup_time_translations
            store_translations :de, {
              :time => {
                :formats => {
                  :default => "%a, %d. %b %Y %H:%M:%S %z",
                  :short => "%d. %b %H:%M",
                  :long => "%d. %B %Y %H:%M",
                  :proc => lambda { |*args| args.inspect }
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
