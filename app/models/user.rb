class User < ApplicationRecord
  # Include default devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # THIS LINE WAS MISSING — ADD IT NOW
  has_many :plaid_items, dependent: :destroy

  # PRD UI-4: Role-based access control
  def admin?
    roles&.include?("admin")
  end

  def parent?
    roles&.include?("parent")
  end

  def kid?
    roles&.include?("kid")
  end

  # PRD UI-4: Family-based scoping for RLS
  scope :for_family, ->(family_id) { where(family_id: family_id) }
end
