require 'active_record'

module I18n
  module Backend
    # ActiveRecord model used to store actual translations to the database.
    #
    # This model expects a table like the following to be already set up in
    # your the database:
    #
    #   create_table :translations do |t|
    #     t.string :locale
    #     t.string :key
    #     t.text   :value
    #     t.text   :interpolations
    #     t.boolean :is_proc, :default => false
    #   end
    #
    # This model supports to named scopes :locale and :lookup. The :locale
    # scope simply adds a condition for a given locale:
    #
    #   I18n::Backend::ActiveRecord::Translation.locale(:en).all
    #   # => all translation records that belong to the :en locale
    #
    # The :lookup scope adds a condition for looking up all translations
    # that either start with the given keys (joined by an optionally given
    # separator or I18n.default_separator) or that exactly have this key.
    #
    #   # with translations present for :"foo.bar" and :"foo.baz"
    #   I18n::Backend::ActiveRecord::Translation.lookup(:foo)
    #   # => an array with both translation records :"foo.bar" and :"foo.baz"
    #
    #   I18n::Backend::ActiveRecord::Translation.lookup([:foo, :bar])
    #   I18n::Backend::ActiveRecord::Translation.lookup(:"foo.bar")
    #   # => an array with the translation record :"foo.bar"
    #
    # When the StoreProcs module was mixed into this model then Procs will
    # be stored to the database as Ruby code and evaluated when :value is
    # called.
    #
    #   Translation = I18n::Backend::ActiveRecord::Translation
    #   Translation.create \
    #     :locale => 'en'
    #     :key    => 'foo'
    #     :value  => lambda { |key, options| 'FOO' }
    #   Translation.find_by_locale_and_key('en', 'foo').value
    #   # => 'FOO'
    class ActiveRecord
      class Translation < ::ActiveRecord::Base
        set_table_name 'translations'
        attr_protected :is_proc, :interpolations

        serialize :value
        serialize :interpolations, Array

        scope_method = ::ActiveRecord::VERSION::MAJOR == 2 ? :named_scope : :scope

        send scope_method, :locale, lambda { |locale|
          { :conditions => { :locale => locale.to_s } }
        }

        send scope_method, :lookup, lambda { |keys, *separator|
          column_name = connection.quote_column_name('key')
          keys        = Array(keys).map! { |key| key.to_s }
          separator   = separator.first || I18n.default_separator
          namespace   = "#{keys.last}#{separator}%"
          { :conditions => ["#{column_name} IN (?) OR #{column_name} LIKE ?", keys, namespace] }
        }

        def self.available_locales
          Translation.find(:all, :select => 'DISTINCT locale').map { |t| t.locale.to_sym }
        end

        def interpolates?(key)
          self.interpolations.include?(key) if self.interpolations
        end

        def value
          if is_proc
            Kernel.eval(read_attribute(:value))
          else
            value = read_attribute(:value)
            value == 'f' ? false : value
          end
        end
      end
    end
  end
end
