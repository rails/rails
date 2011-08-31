if RUBY_VERSION < '1.9.2'

# :stopdoc:
class IO
  def self.binread(name, length = nil, offset = nil)
    return File.read name unless length || offset
    File.open(name, 'rb') { |f|
      f.seek offset if offset
      f.read length
    }
  end
end
# :startdoc:

end
