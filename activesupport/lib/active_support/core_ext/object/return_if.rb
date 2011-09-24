class Object
  def return_if(&block)
    (yield(self) || nil) && self
  end
end
