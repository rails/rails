module TestingSandbox
  # Temporarily replaces KCODE for the block
  def with_kcode(kcode)
    old_kcode, $KCODE = $KCODE, kcode
    begin
      yield
    ensure
      $KCODE = old_kcode
    end
  end
end
