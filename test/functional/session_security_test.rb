# frozen_string_literal: true

require 'test_helper'

# Exercises the real encrypted cookie store, so a "copied" cookie here behaves
# like one taken from a browser.
class SessionSecurityTest < ActionDispatch::IntegrationTest
  SESSION_COOKIE = '_odontome_session'

  setup do
    @user = users(:founder)
  end

  test 'a copied session cookie stops working after a password reset' do
    copied_cookie = signed_in_cookie
    @user.update_columns(perishable_token: 'reset_token_abc', updated_at: 1.minute.ago)

    patch '/password_resets/reset_token_abc', params: { password: 'brand-new-pass' }
    assert_redirected_to root_path

    assert_signed_out_with copied_cookie
  end

  test 'a copied session cookie stops working after the user changes their own password' do
    copied_cookie = signed_in_cookie
    device = signed_in_session

    device.put "/users/#{@user.id}", params: { user: { password: 'brand-new-pass', password_confirmation: 'brand-new-pass' } }
    device.assert_redirected_to "/users/#{@user.id}"

    assert_signed_out_with copied_cookie
    # The device that made the change stays signed in
    device.get '/user_session'
    device.assert_redirected_to root_url
  end

  test 'a session cookie keeps working until the password changes' do
    assert_signed_in_with signed_in_cookie
  end

  test 'the session expires on the server after being idle too long' do
    copied_cookie = signed_in_cookie
    idle_limit = Rails.application.config.session_options[:expire_after]

    travel(idle_limit - 1.minute) { assert_signed_in_with copied_cookie }
    travel(idle_limit + 1.minute) { assert_signed_out_with copied_cookie }
  end

  private

  def signed_in_session
    open_session do |s|
      s.post '/user_session', params: { signin: { email: @user.email, password: '1234567890' } }
      s.assert_redirected_to root_url
    end
  end

  def signed_in_cookie
    signed_in_session.cookies[SESSION_COOKIE].tap { |value| assert value.present? }
  end

  # Sends the cookie by hand, ignoring the browser-side expiry, so only the
  # server decides whether it is still valid.
  def request_with_cookie(cookie)
    open_session do |s|
      s.cookies[SESSION_COOKIE] = cookie
      s.get '/user_session'
    end
  end

  def assert_signed_in_with(cookie)
    request_with_cookie(cookie).assert_redirected_to root_url
  end

  def assert_signed_out_with(cookie)
    request_with_cookie(cookie).assert_redirected_to signin_path
  end
end
