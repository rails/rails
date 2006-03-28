class Symbol #:nodoc:
  def to_proc
    Proc.new { |obj, *args| obj.send(self, *args) }
  end
end
