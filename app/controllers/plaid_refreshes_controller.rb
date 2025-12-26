class PlaidRefreshesController < ApplicationController
  before_action :authenticate_user!
  
  # PRD 0050: Force Full Update Feature
  def create
    item = PlaidItem.find_by(id: params[:id])
    product = params[:product]

    unless item
      flash[:alert] = "Item not found"
      return redirect_to mission_control_path
    end

    # Authorization: only owner (or admin) can trigger refresh
    # Based on existing patterns in mission_control_controller
    unless current_user.roles.include?("owner") || current_user.roles.include?("admin")
      flash[:alert] = "Unauthorized"
      return redirect_to authenticated_root_path
    end

    if item.last_force_at.present? && item.last_force_at > 24.hours.ago
      flash[:alert] = "Rate limit hit: You can only force refresh an item once every 24 hours."
      return redirect_to mission_control_path
    end

    ForcePlaidSyncJob.perform_later(item.id, product)
    
    flash[:notice] = "Enqueued force refresh for #{product} on #{item.institution_name}."
    redirect_to mission_control_path
  end
end
