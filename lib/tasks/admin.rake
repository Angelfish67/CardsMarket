namespace :admin do
  desc "Grant the first admin role to an existing user: ADMIN_USERNAME=name bin/rails admin:bootstrap"
  task bootstrap: :environment do
    username = ENV.fetch("ADMIN_USERNAME", "").strip.downcase
    abort "Set ADMIN_USERNAME to the existing account's username." if username.blank?
    User.transaction do
      User.connection.execute("SELECT pg_advisory_xact_lock(7241901)")
      abort "An active admin already exists. Use the admin panel to change roles." if User.admin.where(suspended: false).exists?
      user = User.lock.find_by!(username: username)
      abort "Unsuspend this account before granting admin access." if user.suspended?
      user.update!(role: :admin)
      AdminActivity.record!(admin: user, subject: user, action: "permissions", details: user.saved_changes.slice("role"))
      puts "Admin access granted to #{user.username}. Sign in again."
    end
  end
end
