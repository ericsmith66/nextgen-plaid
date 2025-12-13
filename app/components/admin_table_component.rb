# frozen_string_literal: true

class AdminTableComponent < ViewComponent::Base
  def initialize(items:, columns:, model_name:)
    @items = items
    @columns = columns
    @model_name = model_name
  end
end
