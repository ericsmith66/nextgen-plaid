class SapCollaboratePolicy < ApplicationPolicy
  def index?
    admin_or_owner?
  end
end
