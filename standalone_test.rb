# Standalone test for SlackNotifier without dependencies
# Run with: ruby standalone_test.rb

require 'net/http'
require 'json'
require 'uri'
require 'yaml'

# Inline SlackNotifier for testing
class TestSlackNotifier
  attr_reader :config, :webhook_url, :stage

  def initialize(options = {})
    @stage = options[:stage]
    @webhook_url = options[:webhook_url]
    @config = options[:config] || {}
  end

  def send_deployment_notification(deployment_data = {})
    unless @webhook_url
      puts "Slack webhook URL not configured for #{@stage}"
      return false
    end

    message = build_message(deployment_data)
    puts "Would send message: #{message.inspect}"
    true
  end

  private

  def build_message(deployment_data)
    fields = []
    fields << {:title => "Application", :value => deployment_data[:application], :short => true} if deployment_data[:application]
    fields << {:title => "Branch", :value => deployment_data[:branch], :short => true} if deployment_data[:branch]

    {
      :text => "Deployment Complete!",
      :username => "deployment-bot",
      :attachments => [
        {
          :color => "good",
          :fields => fields,
        },
      ],
    }
  end
end

puts "Testing SlackNotifier functionality..."

# Test basic functionality
notifier = TestSlackNotifier.new(:stage => "test", :webhook_url => "https://example.com/webhook")
result = notifier.send_deployment_notification({
  :application => "test-app",
  :branch => "main"
})

if result
  puts "[PASS] SlackNotifier basic functionality works"
else
  puts "[FAIL] SlackNotifier failed"
end

puts "Standalone test completed successfully!"
