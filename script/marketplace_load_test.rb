# Run with: RAILS_ENV=test bundle exec ruby script/marketplace_load_test.rb
# Uses only temporary records in the test DB and a private localhost server.
ENV["RAILS_ENV"] ||= "test"
abort "This load test only runs in RAILS_ENV=test." unless ENV["RAILS_ENV"] == "test"

require_relative "../config/environment"
require "net/http"
require "socket"
require "rbconfig"

class MarketplaceLoadTest
  USERS = 10
  SERVER_THREADS = 3 # Match the default Puma configuration.
  OFFERS = 1000
  REQUESTS_PER_USER = 30

  def run
    seed
    start_server
    clients = @users.map { |user| login(user) }
    profiles = [
      [ "newest", "/marketplace/index" ],
      [ "page_20", "/marketplace/index?page=20" ],
      [ "name", "/marketplace/index?q=LoadTest" ],
      [ "rarity_rank", "/marketplace/index?rarity=legendary&rank=E" ],
      [ "combined", "/marketplace/index?q=LoadTest&rarity=rare&rank=E" ]
    ]
    clients.each { |client| check(client[:http].get(profiles.first.last, "Cookie" => client[:cookie])) }
    ready = Queue.new
    release = Queue.new
    samples = Queue.new
    workers = clients.map do |client|
      Thread.new do
        ready << true
        release.pop
        REQUESTS_PER_USER.times do |index|
          label, path = profiles[index % profiles.length]
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          begin
            response = client[:http].get(path, "Cookie" => client[:cookie])
            elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
            check(response)
            samples << { profile: label, seconds: elapsed, status: response.code.to_i }
          rescue StandardError => error
            samples << { profile: label, error: error.class.name, message: error.message }
          end
        end
      end
    end
    USERS.times { ready.pop }
    USERS.times { release << true }
    workers.each(&:value)
    rows = []
    rows << samples.pop until samples.empty?
    times = rows.filter_map { |row| row[:seconds] }.sort
    report = {
      measured_at: Time.now.utc.iso8601, environment: Rails.env,
      ruby: RUBY_VERSION, rails: Rails.version, platform: RUBY_PLATFORM,
      measurement: "Complete HTTP HTML responses from localhost Puma; excludes browser rendering and external images.",
      concurrent_users: USERS, offers_created: OFFERS, active_offers_total: MarketOffer.active.count,
      server_threads: SERVER_THREADS, warmup_requests: USERS, requests: rows.size,
      errors: rows.select { |row| row[:error] },
      p50_seconds: percentile(times, 50), p95_seconds: percentile(times, 95),
      max_seconds: times.max, target_seconds: 2,
      profiles: rows.group_by { |row| row[:profile] }.transform_values do |group|
        values = group.filter_map { |row| row[:seconds] }.sort
        { requests: group.size, p95_seconds: percentile(values, 95), max_seconds: values.max }
      end,
      passed: rows.all? { |row| row[:status] == 200 && row[:seconds] < 2 }
    }
    path = Rails.root.join("docs/marketplace-load-test.json")
    File.write(path, JSON.pretty_generate(report) + "\n")
    puts JSON.pretty_generate(report)
    report[:passed]
  ensure
    clients&.each { |client| client[:http].finish if client[:http].started? }
    stop_server
    cleanup
  end

  private

  def seed
    token = SecureRandom.hex(5)
    @password = SecureRandom.hex(16)
    User.transaction do
      @users = USERS.times.map do |i|
        User.create!(username: "load_#{token}_#{i}", email_address: "load_#{token}_#{i}@example.test",
          password: @password, starter_pack_opened_at: Time.current)
      end
      @pack = Pack.create!(name: "LoadTest #{token}", price: 100, cards_count: 3)
      @types = BrainrotType.rarities.keys.map do |rarity|
        BrainrotType.create!(name: "LoadTest #{token} #{rarity}", rarity: rarity, base_value: 100)
      end
      rank = Rank.find_by(name: "E")
      @created_rank = Rank.create!(name: "E", multiplier: 1, weight: 50) unless rank
      rank ||= @created_rank
      openings = @users.map { |user| PackOpening.create!(user: user, pack: @pack, coins_spent: 0) }
      timestamp = Time.current
      rows = OFFERS.times.map do |i|
        owner = i % USERS
        { user_id: @users[owner].id, brainrot_type_id: @types[i % @types.size].id,
          rank_id: rank.id, pack_opening_id: openings[owner].id, created_at: timestamp, updated_at: timestamp }
      end
      cards = BrainrotCard.insert_all!(rows, returning: %w[id user_id]).rows
      MarketOffer.insert_all!(cards.map do |id, owner_id|
        { brainrot_card_id: id, user_id: owner_id, price: 100, status: 0,
          created_at: timestamp, updated_at: timestamp }
      end)
    end
    puts "Prepared #{OFFERS} offers for #{USERS} temporary accounts."
  end

  def start_server
    socket = TCPServer.new("127.0.0.1", 0)
    @port = socket.addr[1]
    socket.close
    @log = File.open(Rails.root.join("tmp/marketplace-load-test-server.log"), "w")
    @pid = Process.spawn({ "RAILS_ENV" => "test", "RAILS_MAX_THREADS" => SERVER_THREADS.to_s },
      RbConfig.ruby, "bin/rails", "server", "-b", "127.0.0.1", "-p", @port.to_s,
      "-P", "tmp/pids/marketplace-load-test.pid", chdir: Rails.root.to_s,
      out: @log, err: [ :child, :out ])
    120.times do
      begin
        return if http_client.get("/up").code == "200"
      rescue Errno::ECONNREFUSED, EOFError
        # Wait for this process's private Puma to start.
      end
      sleep 0.25
    end
    raise "Load-test server did not start; see tmp/marketplace-load-test-server.log"
  end

  def http_client
    Net::HTTP.new("127.0.0.1", @port, nil).tap do |http|
      http.open_timeout = 5
      http.read_timeout = 15
    end
  end

  def login(user)
    http = http_client
    http.start
    response = http.post("/session", URI.encode_www_form(email_address: user.email_address, password: @password),
      "Content-Type" => "application/x-www-form-urlencoded")
    raise "Login failed for temporary load-test account" unless response.is_a?(Net::HTTPRedirection)
    cookie = response.get_fields("set-cookie").to_a.map { |value| value.split(";").first }.join("; ")
    raise "No authentication cookie received" unless cookie.include?("session_id=")
    { http: http, cookie: cookie }
  end

  def check(response)
    unless response.code == "200" && response.body.include?('data-controller="marketplace"')
      raise "Expected authenticated marketplace HTML, got HTTP #{response.code}"
    end
  end

  def percentile(values, percent)
    values[(values.length * percent / 100.0).ceil - 1] unless values.empty?
  end

  def stop_server
    return unless @pid

    Process.kill("TERM", @pid)
    Process.wait(@pid)
  rescue Errno::ESRCH, Errno::ECHILD
    nil
  ensure
    @log&.close
  end

  def cleanup
    return unless @users

    ids = @users.map(&:id)
    User.transaction do
      MarketOffer.where(user_id: ids).delete_all
      BrainrotCard.where(user_id: ids).delete_all
      PackOpening.where(user_id: ids).delete_all
      Session.where(user_id: ids).delete_all
      User.where(id: ids).delete_all
      @pack&.destroy! if @pack&.persisted?
      @types&.each { |type| type.destroy! if type.persisted? }
      @created_rank&.destroy! if @created_rank&.persisted?
    end
    puts "Temporary load-test data removed."
  end
end

exit(MarketplaceLoadTest.new.run ? 0 : 1)
