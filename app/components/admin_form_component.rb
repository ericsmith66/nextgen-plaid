# frozen_string_literal: true

class AdminFormComponent < ViewComponent::Base
  def initialize(model:, url:, method: :post)
    @model = model
    @url = url
    @method = method
  end
end
