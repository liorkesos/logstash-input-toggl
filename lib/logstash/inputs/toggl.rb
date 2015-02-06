# encoding: utf-8
require "logstash/inputs/base"
require "logstash/namespace"
require "socket" # for Socket.gethostname

# Pull time entries from detailed report Toggl API.
#
# Detailed report URL: GET https://toggl.com/reports/api/v2/details
class LogStash::Inputs::Toggl < LogStash::Inputs::Base

  config_name "toggl"

  milestone 1

  # Interval to run the command. Value is in seconds.
  config :interval, :validate => :number, :required => true

  # API Token
  config :api_token, :validate => :string, :required => true

  # Workspace ID
  #
  # The workspace which data you want to access.
  config :workspace_id, :validate => :string, :required => true

  # User Agent
  #
  # The name of your application or your email address so we can get in touch in case you're doing something wrong.
  config :user_agent, :validate => :string, :required => true

  # Since
  #
  # ISO 8601 date (YYYY-MM-DD), by default until - 6 days.
  config :since, :validate => :string, :required => false

  public
  def register
    require "faraday"
    require "json"

    if since
      addon = "since=#{ @since }"
    else
      addon = ""
    end

    @url = "https://toggl.com/reports/api/v2/details?workspace_id=#{ @workspace_id }&user_agent=#{ @user_agent }&#{ addon }"
    @logger.info? && @logger.info("Registering Toggl Input", :url => @url, :interval => @interval)
  end # def register

  public
  def run(queue)
    Stud.interval(@interval) do
      start = Time.now
      @logger.info? && @logger.info("Polling Toggl", :url => @url, :time => start)

      conn = Faraday.new do |builder|
        builder.use Faraday::Request::Retry
        builder.use Faraday::Request::BasicAuthentication, @api_token, 'api_token'
        builder.use Faraday::Response::Logger
        builder.use Faraday::Adapter::NetHttp
      end

      page = 1

      while true
        new_url = @url + "&page=#{ page }"

        response = conn.get new_url
        result = JSON.parse(response.body)

        if result["data"].nil? || result["data"].empty?
          break
        end

        result["data"].each do |rawevent|
          event = LogStash::Event.new(rawevent)
          decorate(event)
          queue << event
        end

        page += 1
      end

      duration = Time.now - start
      @logger.info? && @logger.info("Poll completed", :command => @command, :duration => duration)
    end # loop
  end # def run
end # class LogStash::Inputs::Exec
