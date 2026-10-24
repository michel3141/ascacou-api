class ApplicationController < ActionController::API
  include Graphiti::Rails::Controller
  include ActionController::HttpAuthentication::Token::ControllerMethods

  class NotAuthenticated < StandardError; end

  register_exception NotAuthenticated, status: 401, handler: Graphiti::Rails::ExceptionHandler
  # Version périmée (lock_version) : le client doit recharger, ce n'est pas une faute.
  register_exception ActiveRecord::StaleObjectError, status: 409, handler: Graphiti::Rails::ExceptionHandler

  after_action :renew_token

  # Lu par les ressources via `context.current_user`.
  def current_user
    return @current_user if defined?(@current_user)

    @current_user = authenticate_with_http_token do |token, _options|
      @token_payload = AuthToken.decode(token)
      User.find_by(id: @token_payload["sub"]) if @token_payload
    end
  end

  private

  def require_user!
    raise NotAuthenticated unless current_user
  end

  def renew_token
    return unless current_user && AuthToken.renew?(@token_payload)

    response.set_header("X-JWT", AuthToken.issue(current_user))
  end
end
