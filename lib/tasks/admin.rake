namespace :admin do
  desc "Create the local development admin account for CMS testing"
  task local: :environment do
    abort "This account is only available in development." unless Rails.env.development?

    user = User.find_or_initialize_by(email: "admin@admin.com")
    user.assign_attributes(admin: true, password: "admin", password_confirmation: "admin")
    # Devise requires six characters. This deliberately short, requested test
    # password is confined to the local development database.
    user.save!(validate: false)
    puts "Local admin ready: #{user.email}"
  end

  desc "Grant admin access: bin/rails 'admin:promote[me@example.com]'"
  task :promote, [ :email ] => :environment do |_task, args|
    user = User.find_by(email: args[:email])
    abort "No user with email #{args[:email].inspect}" if user.nil?

    user.update!(admin: true)
    puts "#{user.email} is now an admin."
  end

  desc "Revoke admin access: bin/rails 'admin:demote[me@example.com]'"
  task :demote, [ :email ] => :environment do |_task, args|
    user = User.find_by(email: args[:email])
    abort "No user with email #{args[:email].inspect}" if user.nil?

    user.update!(admin: false)
    puts "#{user.email} is no longer an admin."
  end

  desc "List admins"
  task list: :environment do
    admins = User.where(admin: true).order(:email)
    puts admins.any? ? admins.map(&:email) : "No admins yet."
  end
end
