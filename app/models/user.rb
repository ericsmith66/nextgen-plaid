class User < ApplicationRecord
  # Include default devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # THIS LINE WAS MISSING — ADD IT NOW
  has_many :plaid_items, dependent: :destroy
end
