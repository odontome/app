module UsersHelper
  def is_editeable_by_current_user(user)
    if user_is_admin?(current_user)
      return true
    elsif user_is_admin?(user)
      return false
    else
      return true
    end
  end
end
