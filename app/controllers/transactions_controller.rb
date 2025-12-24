class TransactionsController < ApplicationController
  before_action :set_transaction, only: [ :show, :edit, :update, :destroy ]

  # GET /transactions
  def index
    @transactions = Transaction.includes(:account)
    # Filtering
    @transactions = @transactions.where(subtype: params[:subtype]) if params[:subtype].present?
    # Sorting (server-side, whitelist)
    sort_col = safe_sort_column(params[:sort])
    sort_dir = %w[asc desc].include?(params[:dir].to_s.downcase) ? params[:dir].to_s.downcase : 'desc'
    @transactions = @transactions.order(Arel.sql("#{sort_col} #{sort_dir}"))
    @transactions = @transactions.page(params[:page]).per(25)
  end

  # GET /transactions/1
  def show
  end

  # GET /transactions/new
  def new
    @transaction = Transaction.new
  end

  # GET /transactions/1/edit
  def edit
  end

  # POST /transactions
  def create
    @transaction = Transaction.new(transaction_params)

    if @transaction.save
      redirect_to @transaction, notice: "Transaction was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /transactions/1
  def update
    if @transaction.update(transaction_params)
      redirect_to @transaction, notice: "Transaction was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /transactions/1
  def destroy
    @transaction.destroy
    redirect_to transactions_url, notice: "Transaction was successfully destroyed."
  end

  private
    def set_transaction
      @transaction = Transaction.find(params[:id])
    end

    def transaction_params
      params.require(:transaction).permit(:account_id, :transaction_id, :amount, :date,
                                          :name, :merchant_name, :subtype, :category,
                                          :pending, :payment_channel)
    end

    # Only allow ordering by these columns to avoid SQL injection
    def safe_sort_column(param)
      allowed = {
        'date' => 'date',
        'name' => 'name',
        'amount' => 'amount',
        'subtype' => 'subtype',
        'fees' => 'fees'
      }
      allowed[param.to_s] || 'date'
    end
end
