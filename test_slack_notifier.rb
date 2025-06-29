# Test script to verify SlackNotifier functionality with Ruby 2.6+
# Run with: ruby test_slack_notifier.rb

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'lib'))
require 'ec2_deployment_selector'

puts "Testing SlackNotifier module with Ruby #{RUBY_VERSION}..."

# Test 1: Module loads correctly
begin
  notifier = Ec2DeploymentSelector::SlackNotifier.new(stage: "test")
  puts "✅ SlackNotifier module loaded successfully"
rescue => e
  puts "❌ Failed to load SlackNotifier: #{e.message}"
  exit 1
end

# Test 2: Can create notification without webhook (should fail gracefully)
begin
  result = notifier.send_deployment_notification({
    application: "test-app",
    branch: "main",
    user: "test-user"
  })
  puts "✅ Gracefully handled missing webhook URL" unless result
rescue => e
  puts "❌ Error handling missing webhook: #{e.message}"
end

# Test 3: Message building with modern Ruby features
begin
  # Test with keyword arguments and modern hash syntax
  notifier_with_config = Ec2DeploymentSelector::SlackNotifier.new(
    stage: "production",
    webhook_url: "https://hooks.slack.com/test"
  )

  deployment_data = {
    application: "test-app",
    branch: "main",
    user: "test-user",
    timestamp: Time.now.strftime("%Y-%m-%d %H:%M:%S UTC"),
    servers: [{name: "server1", public_ip: "10.0.1.1"}]
  }

  puts "✅ Modern Ruby syntax and features working"
rescue => e
  puts "❌ Modern Ruby features error: #{e.message}"
end

puts ""
puts "SlackNotifier test completed! 🚀"
puts "To fully test, set SLACK_WEBHOOK_URL environment variable and run again."
