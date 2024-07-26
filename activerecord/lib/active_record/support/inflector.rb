module Inflector
  extend self

  PluralRules = [
    [/(x|ch|ss)$/, '\1es'],               # search, switch, fix, box, process, address
    [/([^aeiouy]|qu)y$/, '\1ies'],        # query, ability, agency
    [/(?:([^f])fe|([lr])f)$/, '\1\2ves'], # half, safe, wife
    [/person$/, 'people'],                # person, salesperson
    [/man$/, 'men'],                      # man, woman, spokesman
    [/sis$/, 'ses'],                      # basis, diagnosis
    [/([ti])um$/, '\1a'],                 # datum, medium
    [/child$/, 'children'],               # child
    [/s$/, 's'],                          # no change (compatibility)
    [/$/, 's']
  ]

  SingularRules = [
    [/(x|ch|ss)es$/, '\1'],
    [/([^aeiouy]|qu)ies$/, '\1y'],
    [/([lr])ves$/, '\1f'],
    [/([^f])ves$/, '\1fe'],
    [/people$/, 'person'],
    [/men$/, 'man'],
    [/ses$/, 'sis'],
    [/([ti])a/, '\1um'],
    [/children$/, 'child'],
    [/s$/, '']
  ]

  def pluralize(word)
    result = word.dup
    PluralRules.each do |(rule, replacement)|
      break if result.gsub!(rule, replacement)
    end
    return result
  end

  def singularize(word)
    result = word.dup
    SingularRules.each do |(rule, replacement)|
      break if result.gsub!(rule, replacement)
    end
    return result
  end
end
