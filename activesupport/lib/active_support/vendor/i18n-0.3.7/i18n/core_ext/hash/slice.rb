# from facets (http://facets.rubyforge.org)
class Hash
  def slice(*keep_keys)
    h = {}
    keep_keys.each { |key| h[key] = fetch(key) }
    h
  end
end unless Hash.new.respond_to?(:slice)