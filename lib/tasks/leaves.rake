namespace :leaves do
  desc "Grant default leave entitlements to all employees for a year (idempotent)"
  task :grant_entitlements, [ :year ] => :environment do |_task, args|
    Leaves::GrantEntitlements.backfill(year: Integer(args.fetch(:year, Date.current.year)))
  end
end
