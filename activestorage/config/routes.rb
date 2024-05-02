# frozen_string_literal: true

Rails.application.routes.draw { ActiveStorage::Routes.draw(self) } if ActiveStorage.draw_routes
