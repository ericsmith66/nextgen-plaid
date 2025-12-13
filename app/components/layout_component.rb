# frozen_string_literal: true

class LayoutComponent < ViewComponent::Base
  def initialize(title: "NextGen Wealth", current_user: nil)
    @title = title
    @current_user = current_user
  end
end
