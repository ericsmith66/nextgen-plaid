class HoldingsController < ApplicationController
  before_action :set_holding, only: [ :show, :edit, :update, :destroy ]

  # GET /holdings
  def index
    @holdings = Holding.includes(:account).page(params[:page]).per(25)
  end

  # GET /holdings/1
  def show
  end

  # GET /holdings/new
  def new
    @holding = Holding.new
  end

  # GET /holdings/1/edit
  def edit
  end

  # POST /holdings
  def create
    @holding = Holding.new(holding_params)

    if @holding.save
      redirect_to @holding, notice: "Holding was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /holdings/1
  def update
    if @holding.update(holding_params)
      redirect_to @holding, notice: "Holding was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /holdings/1
  def destroy
    @holding.destroy
    redirect_to holdings_url, notice: "Holding was successfully destroyed."
  end

  private
    def set_holding
      @holding = Holding.find(params[:id])
    end

    def holding_params
      params.require(:holding).permit(:account_id, :security_id, :name, :symbol,
                                      :quantity, :cost_basis, :market_value, :vested_value,
                                      :institution_price, :sector, :type)
    end
end
