# encoding: utf-8

module Tests
  module Api
    module Localization
      module Procs
        define_method "test localize: using day names from lambdas" do
          setup_time_proc_translations
          time = ::Time.parse('2008-03-01 6:00 UTC')
          assert_match /Суббота/, I18n.l(time, :format => "%A, %d %B", :locale => :ru)
          assert_match /суббота/, I18n.l(time, :format => "%d %B (%A)", :locale => :ru)
        end

        define_method "test localize: using month names from lambdas" do
          setup_time_proc_translations
          time = ::Time.parse('2008-03-01 6:00 UTC')
          assert_match /марта/, I18n.l(time, :format => "%d %B %Y", :locale => :ru)
          assert_match /Март /, I18n.l(time, :format => "%B %Y", :locale => :ru)
        end

        define_method "test localize: using abbreviated day names from lambdas" do
          setup_time_proc_translations
          time = ::Time.parse('2008-03-01 6:00 UTC')
          assert_match /марта/, I18n.l(time, :format => "%d %b %Y", :locale => :ru)
          assert_match /март /, I18n.l(time, :format => "%b %Y", :locale => :ru)
        end

        protected

          def setup_time_proc_translations
            store_translations :ru, {
              :date => {
                :'day_names' => lambda { |key, options|
                  (options[:format] =~ /^%A/) ?
                  %w(Воскресенье Понедельник Вторник Среда Четверг Пятница Суббота) :
                  %w(воскресенье понедельник вторник среда четверг пятница суббота)
                },
                :'month_names' => lambda { |key, options|
                  (options[:format] =~ /(%d|%e)(\s*)?(%B)/) ?
                  %w(января февраля марта апреля мая июня июля августа сентября октября ноября декабря).unshift(nil) :
                  %w(Январь Февраль Март Апрель Май Июнь Июль Август Сентябрь Октябрь Ноябрь Декабрь).unshift(nil)
                },
                :'abbr_month_names' => lambda { |key, options|
                  (options[:format] =~ /(%d|%e)(\s*)(%b)/) ?
                  %w(янв. февр. марта апр. мая июня июля авг. сент. окт. нояб. дек.).unshift(nil) :
                  %w(янв. февр. март апр. май июнь июль авг. сент. окт. нояб. дек.).unshift(nil)
                },
              }
            }
          end
      end
    end
  end
end
