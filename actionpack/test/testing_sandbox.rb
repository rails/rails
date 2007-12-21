module TestingSandbox
  # Temporarily replaces KCODE for the block
  def with_kcode(kcode)
    if RUBY_VERSION < '1.9'
      old_kcode, $KCODE = $KCODE, kcode
      begin
        yield
      ensure
        $KCODE = old_kcode
      end
    else
      yield
    end
  end
end
