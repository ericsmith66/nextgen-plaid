module Admin
  class AiWorkflowController < ApplicationController
    layout "admin"

    before_action :authenticate_user!
    before_action :require_admin!

    def index
      @tab = params[:tab].to_s.presence_in(%w[ownership context logs]) || "ownership"

      @snapshot = AiWorkflowSnapshot.load_latest(
        correlation_id: params[:correlation_id].presence,
        events_limit: 500
      )

      @events_page = params[:events_page].to_i
      @events_page = 1 if @events_page < 1
      @events_per_page = 100
    end

    private

    def require_admin!
      head :forbidden unless current_user&.admin?
    end
  end
end
