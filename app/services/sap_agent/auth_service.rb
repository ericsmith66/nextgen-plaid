module SapAgent
  class AuthService
    def initialize(user)
      @user = user
    end

    def owner?
      @user&.owner?
    end

    def admin?
      @user&.admin?
    end

    private

    attr_reader :user
  end
end
