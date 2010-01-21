# encoding: utf-8

module Tests
  module Api
    module Link
      define_method "test linked lookup: if a key resolves to a symbol it looks up the symbol" do
        I18n.backend.store_translations 'en', {
          :link  => :linked,
          :linked => 'linked'
        }
        assert_equal 'linked', I18n.backend.translate('en', :link)
      end

      define_method "test linked lookup: if a key resolves to a dot-separated symbol it looks up the symbol" do
        I18n.backend.store_translations 'en', {
          :link => :"foo.linked",
          :foo  => { :linked => 'linked' }
        }
        assert_equal('linked', I18n.backend.translate('en', :link))
      end

      define_method "test linked lookup: if a dot-separated key resolves to a symbol it looks up the symbol" do
        I18n.backend.store_translations 'en', {
          :foo    => { :link => :linked },
          :linked => 'linked'
        }
        assert_equal('linked', I18n.backend.translate('en', :'foo.link'))
      end
      
      define_method "test linked lookup: if a dot-separated key resolves to a dot-separated symbol it looks up the symbol" do
        I18n.backend.store_translations 'en', {
          :foo => { :link   => :"bar.linked" },
          :bar => { :linked => 'linked' }
        }
        assert_equal('linked', I18n.backend.translate('en', :'foo.link'))
      end
      
      define_method "test linked lookup: links refer to absolute keys even if a scope was given" do
        I18n.backend.store_translations 'en', {
          :foo => { :link  => :linked, :linked => 'linked in foo' },
          :linked => 'linked absolutely'
        }
        assert_equal 'linked absolutely', I18n.backend.translate('en', :link, :scope => :foo)
      end

      define_method "test linked lookup: a link can resolve to a namespace in the middle of a dot-separated key" do
        I18n.backend.store_translations 'en', {
          :activemodel  => { :errors => { :messages => { :blank => "can't be blank" } } },
          :activerecord => { :errors => { :messages => :"activemodel.errors.messages" } }
        }
        assert_equal "can't be blank", I18n.t(:"activerecord.errors.messages.blank")
      end
    end
  end
end
