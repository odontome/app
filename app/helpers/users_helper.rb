# frozen_string_literal: true

module UsersHelper
  def is_editeable_by_current_user(user)
    if user_is_admin?(current_user)
      true
    elsif user_is_admin?(user)
      false
    else
      true
    end
  end
end
