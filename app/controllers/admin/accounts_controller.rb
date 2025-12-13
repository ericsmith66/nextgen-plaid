class Admin::AccountsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_account, only: [:show, :edit, :update, :destroy]

  def index
    @accounts = if current_user.admin?
                  Account.includes(:plaid_item).all
                else
                  Account.joins(:plaid_item).where(plaid_items: { user_id: current_user.id })
                end
    @accounts = @accounts.page(params[:page]).per(25)
  end

  def show
  end

  def new
    @account = Account.new
  end

  def create
    @account = Account.new(account_params)

    if @account.save
      redirect_to admin_account_path(@account), notice: "Account was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @account.update(account_params)
      redirect_to admin_account_path(@account), notice: "Account was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @account.destroy
    redirect_to admin_accounts_path, notice: "Account was successfully deleted."
  end

  private

  def set_account
    @account = Account.find(params[:id])
  end

  def account_params
    params.require(:account).permit(:name, :type, :subtype, :mask, :current_balance, :plaid_item_id)
  end

  def require_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: "Access denied. Admin privileges required."
    end
  end
end
