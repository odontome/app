class UserSession < Authlogic::Session::Base
  consecutive_failed_logins_limit 10
  failed_login_ban_for 30.minutes
end
