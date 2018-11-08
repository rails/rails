class Mail::Message
  def from_address
    header[:from]&.address_list&.addresses&.first
  end

  def recipients_addresses
    to_addresses + cc_addresses + bcc_addresses
  end

  def to_addresses
    Array(header[:to]&.address_list&.addresses)
  end

  def cc_addresses
    Array(header[:cc]&.address_list&.addresses)
  end

  def bcc_addresses
    Array(header[:bcc]&.address_list&.addresses)
  end
end
