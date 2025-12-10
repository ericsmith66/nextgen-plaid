class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    # You will see this flash – proof you're in the right place
    flash.now[:success] = "SECURE DASHBOARD – Connect Brokerage Account below"
  end
end
