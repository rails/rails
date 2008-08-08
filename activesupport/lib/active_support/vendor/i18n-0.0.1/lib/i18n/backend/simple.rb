require 'strscan'

module I18n
  module Backend
    module Simple
      @@translations = {}
      
      class << self
        # Allow client libraries to pass a block that populates the translation
        # storage. Decoupled for backends like a db backend that persist their
        # translations, so the backend can decide whether/when to yield or not.
        def populate(&block)
          yield
        end
        
        # Stores translations for the given locale in memory. 
        # This uses a deep merge for the translations hash, so existing
        # translations will be overwritten by new ones only at the deepest
        # level of the hash.
        def store_translations(locale, data)
          merge_translations(locale, data)
        end
        
        def translate(locale, key, options = {})
          raise InvalidLocale.new(locale) if locale.nil?
          return key.map{|k| translate locale, k, options } if key.is_a? Array

          reserved = :scope, :default
          count, scope, default = options.values_at(:count, *reserved)
          options.delete(:default)
          values = options.reject{|name, value| reserved.include? name }

          entry = lookup(locale, key, scope) || default(locale, default, options) || raise(I18n::MissingTranslationData.new(locale, key, options))
          entry = pluralize entry, count
          entry = interpolate entry, values
          entry
        end
        
        # Acts the same as +strftime+, but returns a localized version of the 
        # formatted date string. Takes a key from the date/time formats 
        # translations as a format argument (<em>e.g.</em>, <tt>:short</tt> in <tt>:'date.formats'</tt>).        
        def localize(locale, object, format = :default)
          raise ArgumentError, "Object must be a Date, DateTime or Time object. #{object.inspect} given." unless object.respond_to?(:strftime)
          
          type = object.respond_to?(:sec) ? 'time' : 'date'
          formats = translate(locale, :"#{type}.formats")
          format = formats[format.to_sym] if formats && formats[format.to_sym]
          # TODO raise exception unless format found?
          format = format.to_s.dup

          format.gsub!(/%a/, translate(locale, :"date.abbr_day_names")[object.wday])
          format.gsub!(/%A/, translate(locale, :"date.day_names")[object.wday])
          format.gsub!(/%b/, translate(locale, :"date.abbr_month_names")[object.mon])
          format.gsub!(/%B/, translate(locale, :"date.month_names")[object.mon])
          format.gsub!(/%p/, translate(locale, :"time.#{object.hour < 12 ? :am : :pm}")) if object.respond_to? :hour
          object.strftime(format)
        end
        
        protected
        
          # Looks up a translation from the translations hash. Returns nil if 
          # eiher key is nil, or locale, scope or key do not exist as a key in the
          # nested translations hash. Splits keys or scopes containing dots
          # into multiple keys, i.e. <tt>currency.format</tt> is regarded the same as
          # <tt>%w(currency format)</tt>.
          def lookup(locale, key, scope = [])
            return unless key
            keys = I18n.send :normalize_translation_keys, locale, key, scope
            keys.inject(@@translations){|result, k| result[k.to_sym] or return nil }
          end
        
          # Evaluates a default translation. 
          # If the given default is a String it is used literally. If it is a Symbol
          # it will be translated with the given options. If it is an Array the first
          # translation yielded will be returned.
          # 
          # <em>I.e.</em>, <tt>default(locale, [:foo, 'default'])</tt> will return +default+ if 
          # <tt>translate(locale, :foo)</tt> does not yield a result.
          def default(locale, default, options = {})
            case default
              when String then default
              when Symbol then translate locale, default, options
              when Array  then default.each do |obj| 
                result = default(locale, obj, options.dup) and return result
              end
            end
          rescue MissingTranslationData
            nil
          end
        
          # Picks a translation from an array according to English pluralization
          # rules. It will pick the first translation if count is not equal to 1
          # and the second translation if it is equal to 1. Other backends can
          # implement more flexible or complex pluralization rules.
          def pluralize(entry, count)
            return entry unless entry.is_a?(Array) and count
            raise InvalidPluralizationData.new(entry, count) unless entry.size == 2
            entry[count == 1 ? 0 : 1]
          end
    
          # Interpolates values into a given string.
          # 
          #   interpolate "file {{file}} opened by \\{{user}}", :file => 'test.txt', :user => 'Mr. X'  
          #   # => "file test.txt opened by {{user}}"
          # 
          # Note that you have to double escape the <tt>\\</tt> when you want to escape
          # the <tt>{{...}}</tt> key in a string (once for the string and once for the
          # interpolation).
          def interpolate(string, values = {})
            return string if !string.is_a?(String)

            map = {'%d' => '{{count}}', '%s' => '{{value}}'} # TODO deprecate this?
            string.gsub!(/#{map.keys.join('|')}/){|key| map[key]} 
          
            s = StringScanner.new string.dup
            while s.skip_until(/\{\{/)
              s.string[s.pos - 3, 1] = '' and next if s.pre_match[-1, 1] == '\\'            
              start_pos = s.pos - 2
              key = s.scan_until(/\}\}/)[0..-3]
              end_pos = s.pos - 1            

              raise ReservedInterpolationKey.new(key, string) if %w(scope default).include?(key)
              raise MissingInterpolationArgument.new(key, string) unless values.has_key? key.to_sym

              s.string[start_pos..end_pos] = values[key.to_sym].to_s
              s.unscan
            end      
            s.string
          end
          
          # Deep merges the given translations hash with the existing translations
          # for the given locale
          def merge_translations(locale, data)
            locale = locale.to_sym
            @@translations[locale] ||= {}
            data = deep_symbolize_keys data

            # deep_merge by Stefan Rusterholz, see http://www.ruby-forum.com/topic/142809
            merger = proc{|key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
            @@translations[locale].merge! data, &merger
          end
          
          # Return a new hash with all keys and nested keys converted to symbols.
          def deep_symbolize_keys(hash)
            hash.inject({}){|result, (key, value)|
              value = deep_symbolize_keys(value) if value.is_a? Hash
              result[(key.to_sym rescue key) || key] = value
              result
            }
          end
      end
    end
  end
end
