# frozen_string_literal: true

class DashboardComponent < ViewComponent::Base
  def initialize(current_user:)
    @current_user = current_user
  end
end
