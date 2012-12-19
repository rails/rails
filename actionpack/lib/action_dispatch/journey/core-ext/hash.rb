# :stopdoc:
if RUBY_VERSION < '1.9'
class Hash
  def keep_if
    each do |k,v|
      delete(k) unless yield(k,v)
    end
  end
end
end
# :startdoc:
