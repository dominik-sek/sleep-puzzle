namespace :admin do
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
