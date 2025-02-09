# frozen_string_literal: true

class AssociationLoadingJob < ArgumentsRoundTripJob
  def perform(record, associations = [])
    associations.each { |association| record.send(association).load }

    super
  end
end
