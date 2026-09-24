require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    assert_equal "downcased@example.com", User.new(email_address: " DOWNCASED@EXAMPLE.COM ").email_address
  end

  test "password must have at least 12 characters and no more than 72 bytes" do
    user = users(:one)
    [ "a" * 11, "a" * 73, "ä" * 37, "" ].each do |password|
      user.password = password
      assert_not user.valid?
      assert user.errors[:password].any?
    end
    [ "a" * 12, "a" * 72 ].each do |password|
      user.password = password
      assert user.valid?
    end
  end

  test "existing users can update non-password fields" do
    assert users(:one).update(coins: 1001)
  end

  test "password digest is salted and password is not a database column" do
    first = User.new(password: "a secure passphrase")
    second = User.new(password: "a secure passphrase")
    assert_not_equal first.password_digest, second.password_digest
    assert BCrypt::Password.new(first.password_digest).is_password?("a secure passphrase")
    assert_not_includes User.column_names, "password"
  end

  test "authenticate_by performs bcrypt work for known and unknown email addresses" do
    [ users(:one).email_address, "unknown@example.com" ].each do |email|
      calls = 0
      trace = TracePoint.new(:call, :c_call) do |event|
        calls += 1 if event.method_id == :hash_secret && event.self == BCrypt::Engine
      end
      result = trace.enable { User.authenticate_by(email_address: email, password: "incorrect password") }
      assert_nil result
      assert_operator calls, :>=, 1, "BCrypt must run for #{email}"
    ensure
      trace&.disable
    end
  end
end
