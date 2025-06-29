# Example Capistrano Integration for Any Repository
# Add this to your config/deploy.rb

require 'ec2_deployment_selector'

# Define all Slack notification tasks
define_slack_notification_tasks

# Option 1: Basic integration (completion notification only)
after :finished, :notify_slack

# Option 2: Full workflow with validation and start/end notifications
# before :deploy, :validate_slack_config    # Validate before deploy
# before :deploy, :notify_slack_start       # Notify on start
# after :finished, :notify_slack            # Notify on completion

# Option 3: Custom integration with additional data
# task :deploy_with_custom_slack do
#   run_locally do
#     send_deployment_notification(nil, {
#       feature: "custom feature name",
#       ticket: "JIRA-123",
#       notes: "Special deployment notes"
#     })
#   end
# end

# Option 4: Test your Slack setup
# Run: cap production test_slack
# Run: cap production validate_slack_config

# Configuration:
# 1. Create config/slack_notifications.yml (see template)
# 2. Or set environment variables:
#    - SLACK_WEBHOOK_URL
#    - SLACK_NOTIFICATIONS_ENABLED=true
#    - SLACK_CHANNEL=#deployments
#    - etc.

# That's it! Your repository now has atomic Slack notifications
# that work independently of any server selection features.
