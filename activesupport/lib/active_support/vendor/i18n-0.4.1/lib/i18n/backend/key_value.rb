# encoding: utf-8

require 'i18n/backend/base'
require 'active_support/json'

module I18n
  module Backend
    # This is a basic backend for key value stores. It receives on
    # initialization the store, which should respond to three methods:
    #
    # * store#[](key)         - Used to get a value
    # * store#[]=(key, value) - Used to set a value
    # * store#keys            - Used to get all keys
    #
    # Since these stores only supports string, all values are converted
    # to JSON before being stored, allowing it to also store booleans,
    # hashes and arrays. However, this store does not support Procs.
    #
    # As the ActiveRecord backend, Symbols are just supported when loading
    # translations from the filesystem or through explicit store translations.
    #
    # Also, avoid calling I18n.available_locales since it's a somehow
    # expensive operation in most stores.
    #
    # == Example
    #
    # To setup I18n to use TokyoCabinet in memory is quite straightforward:
    #
    #   require 'rufus/tokyo/cabinet' # gem install rufus-tokyo
    #   I18n.backend = I18n::Backend::KeyValue.new(Rufus::Tokyo::Cabinet.new('*'))
    #
    # == Performance
    #
    # You may make this backend even faster by including the Memoize module.
    # However, notice that you should properly clear the cache if you change
    # values directly in the key-store.
    #
    # == Subtrees
    #
    # In most backends, you are allowed to retrieve part of a translation tree:
    #
    #   I18n.backend.store_translations :en, :foo => { :bar => :baz }
    #   I18n.t "foo" #=> { :bar => :baz }
    #
    # This backend supports this feature by default, but it slows down the storage
    # of new data considerably and makes hard to delete entries. That said, you are
    # allowed to disable the storage of subtrees on initialization:
    #
    #   I18n::Backend::KeyValue.new(@store, false)
    #
    # This is useful if you are using a KeyValue backend chained to a Simple backend.
    class KeyValue
      module Implementation
        attr_accessor :store

        include Base, Flatten

        def initialize(store, subtrees=true)
          @store, @subtrees = store, subtrees
        end

        def store_translations(locale, data, options = {})
          escape = options.fetch(:escape, true)
          flatten_translations(locale, data, escape, @subtrees).each do |key, value|
            key = "#{locale}.#{key}"

            case value
            when Hash
              if @subtrees && (old_value = @store[key])
                old_value = ActiveSupport::JSON.decode(old_value)
                value = old_value.deep_symbolize_keys.deep_merge!(value) if old_value.is_a?(Hash)
              end
            when Proc
              raise "Key-value stores cannot handle procs"
            end

            @store[key] = ActiveSupport::JSON.encode(value) unless value.is_a?(Symbol)
          end
        end

        def available_locales
          locales = @store.keys.map { |k| k =~ /\./; $` }
          locales.uniq!
          locales.compact!
          locales.map! { |k| k.to_sym }
          locales
        end

      protected

        def lookup(locale, key, scope = [], options = {})
          key   = normalize_flat_keys(locale, key, scope, options[:separator])
          value = @store["#{locale}.#{key}"]
          value = ActiveSupport::JSON.decode(value) if value
          value.is_a?(Hash) ? value.deep_symbolize_keys : value
        end
      end

      include Implementation
    end
  end
end