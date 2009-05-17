class Pathname
  def /(path)
    (self + path).expand_path
  end
end
