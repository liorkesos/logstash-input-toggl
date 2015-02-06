# encoding: utf-8
require "logstash/inputs/base"
require "logstash/namespace"
require "socket" # for Socket.gethostname

# Run command line tools and capture the whole output as an event.
#
# Notes:
#
# * The `@source` of this event will be the command run.
# * The `@message` of this event will be the entire stdout of the command
#   as one event.
#
class LogStash::Inputs::Toggl < LogStash::Inputs::Base

  config_name "toggl"

  milestone 1

  # Interval to run the command. Value is in seconds.
  config :interval, :validate => :number, :required => true

  # API Token
  config :api_token, :validate => :string, :required => true

  # Workspace ID
  config :workspace_id, :validate => :string, :required => true

  # Workspace ID
  config :since, :validate => :string, :required => false

  public
  def register
    require "faraday"
    require 'json'

    if since
      addon = "since=#{ @since }"
    else
      addon = ""
    end

    @url = "https://toggl.com/reports/api/v2/details?workspace_id=#{ @workspace_id }&user_agent=logstash&#{ addon }"
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
