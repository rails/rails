# The Inflector transforms words from singular to plural, class names to table names, modularized class names to ones without,
# and class names to foreign keys.
module Inflector 
  extend self

  def pluralize(word)
    result = word.to_s.dup

    if uncountable_words.include?(result.downcase)
      result
    else
      plural_rules.each { |(rule, replacement)| break if result.gsub!(rule, replacement) }
      result
    end
  end

  def singularize(word)
    result = word.to_s.dup

    if uncountable_words.include?(result.downcase)
      result
    else
      singular_rules.each { |(rule, replacement)| break if result.gsub!(rule, replacement) }
      result
    end
  end

  def camelize(lower_case_and_underscored_word)
    lower_case_and_underscored_word.to_s.gsub(/\/(.?)/) { "::" + $1.upcase }.gsub(/(^|_)(.)/) { $2.upcase }
  end
  
  def underscore(camel_cased_word)
    camel_cased_word.to_s.gsub(/::/, '/').gsub(/([A-Z]+)([A-Z])/,'\1_\2').gsub(/([a-z\d])([A-Z])/,'\1_\2').downcase
  end

  def humanize(lower_case_and_underscored_word)
    lower_case_and_underscored_word.to_s.gsub(/_/, " ").capitalize
  end

  def demodulize(class_name_in_module)
    class_name_in_module.to_s.gsub(/^.*::/, '')
  end

  def tableize(class_name)
    pluralize(underscore(class_name))
  end
  
  def classify(table_name)
    camelize(singularize(table_name))
  end

  def foreign_key(class_name, separate_class_name_and_id_with_underscore = true)
    Inflector.underscore(Inflector.demodulize(class_name)) + 
      (separate_class_name_and_id_with_underscore ? "_id" : "id")
  end

  def constantize(camel_cased_word)
    camel_cased_word.split("::").inject(Object) do |final_type, part| 
      final_type = final_type.const_get(part)
    end
  end

  private
    def uncountable_words #:doc
      %w( equipment information rice money species series fish )
    end
  
    def plural_rules #:doc:
      [
      	[/^(ox)$/i, '\1\2en'],		             # ox
      	[/([m|l])ouse$/i, '\1ice'],	           # mouse, louse
      	[/(matr|vert)ix|ex$/i, '\1ices'],      # matrix, vertex, index
        [/(x|ch|ss|sh)$/i, '\1es'],            # search, switch, fix, box, process, address
        [/([^aeiouy]|qu)ies$/i, '\1y'],
        [/([^aeiouy]|qu)y$/i, '\1ies'],        # query, ability, agency
        [/(hive)$/i, '\1s'],                   # archive, hive
        [/(?:([^f])fe|([lr])f)$/i, '\1\2ves'], # half, safe, wife
        [/sis$/i, 'ses'],                      # basis, diagnosis
        [/([ti])um$/i, '\1a'],                 # datum, medium
        [/(p)erson$/i, '\1eople'],             # person, salesperson
        [/(m)an$/i, '\1en'],                   # man, woman, spokesman
        [/(c)hild$/i, '\1hildren'],            # child
      	[/(buffal|tomat)o$/i, '\1\2oes'],		   # buffalo, tomato
      	[/(bu)s$/i, '\1\2ses'],	               # bus
        [/(alias)/i, '\1es'],                  # alias
      	[/(octop|vir)us$/i, '\1i'],            # octopus, virus - virus has no defined plural (according to Latin/dictionary.com), but viri is better than viruses/viruss
      	[/(ax|cri|test)is$/i, '\1es'],         # axis, crisis  
        [/s$/i, 's'],                          # no change (compatibility)
        [/$/, 's']
      ]
    end

    def singular_rules #:doc:
      [
        [/(matr)ices$/i, '\1ix'],
      	[/(vert)ices$/i, '\1ex'],
      	[/^(ox)en/i, '\1'],
      	[/(alias)es$/i, '\1'],
      	[/([octop|vir])i$/i, '\1us'],
      	[/(cris|ax|test)es$/i, '\1is'],
      	[/(shoe)s$/i, '\1'],
      	[/(o)es$/i, '\1'],
      	[/(bus)es$/i, '\1'],
      	[/([m|l])ice$/i, '\1ouse'],
        [/(x|ch|ss|sh)es$/i, '\1'],
        [/(m)ovies$/i, '\1\2ovie'],
        [/(s)eries$/i, '\1\2eries'],
        [/([^aeiouy]|qu)ies$/i, '\1y'],
        [/([lr])ves$/i, '\1f'],
        [/(tive)s$/i, '\1'],
        [/(hive)s$/i, '\1'],
        [/([^f])ves$/i, '\1fe'],
        [/(^analy)ses$/i, '\1sis'],
        [/((a)naly|(b)a|(d)iagno|(p)arenthe|(p)rogno|(s)ynop|(t)he)ses$/i, '\1\2sis'],
        [/([ti])a$/i, '\1um'],
        [/(p)eople$/i, '\1\2erson'],
        [/(m)en$/i, '\1an'],
        [/(s)tatus$/i, '\1\2tatus'],
        [/(c)hildren$/i, '\1\2hild'],
        [/(n)ews$/i, '\1\2ews'],
        [/s$/i, '']
      ]
    end
end