# SlackNotifier Usage Examples

## Basic Usage (Standalone)

```ruby
require 'ec2_deployment_selector'

# Create notifier with webhook URL
notifier = Ec2DeploymentSelector::SlackNotifier.new(
  webhook_url: "https://hooks.slack.com/services/YOUR/WEBHOOK/URL",
  stage: "production"
)

# Send deployment notification
notifier.send_deployment_notification({
  application: "my-app",
  branch: "main",
  user: "deploy-user",
  timestamp: Time.now.strftime("%Y-%m-%d %H:%M:%S UTC"),
  servers: ["server1 (10.0.1.1)", "server2 (10.0.1.2)"]
})
```

## Validation and Testing (Atomic Features)

```ruby
# Validate configuration before deployment
validation = Ec2DeploymentSelector::SlackNotifier.validate_config(
  config_file_path: "config/slack_notifications.yml",
  stage: "production"
)

if validation[:valid]
  puts "✅ Slack notifications properly configured"
else
  puts "❌ Configuration issues: #{validation[:errors].join(', ')}"
end

# Test notifications
Ec2DeploymentSelector::SlackNotifier.test_notification(
  config_file_path: "config/slack_notifications.yml",
  stage: "staging"
)
```

## Custom Messages

```ruby
# Send custom formatted messages
notifier.send_custom_message({
  text: "🚀 Custom deployment message",
  username: "deployment-bot",
  channel: "#deployments",
  attachments: [
    {
      color: "good",
      fields: [
        { title: "Custom Field", value: "Custom Value", short: true }
      ]
    }
  ]
})
```

## Usage with Configuration File

```ruby
# Create config/slack_notifications.yml first (see template)
notifier = Ec2DeploymentSelector::SlackNotifier.new(
  config_file_path: "config/slack_notifications.yml",
  stage: "staging"
)

notifier.send_deployment_notification({
  application: "my-app",
  branch: "develop",
  user: "developer"
})
```

## Enhanced Capistrano Integration

### Basic Setup

Add to your `config/deploy.rb`:

```ruby
require 'ec2_deployment_selector'

# Define all notification tasks
define_slack_notification_tasks

# Add to deployment flow (choose one or both)
before :deploy, :validate_slack_config  # Optional: validate before deploy
after :finished, :notify_slack          # Send completion notification
```

### Available Capistrano Tasks

```bash
# Validate Slack configuration
cap production validate_slack_config

# Test Slack notifications (sends test message)
cap production test_slack

# Send deployment start notification
cap production notify_slack_start

# Send deployment completion notification
cap production notify_slack

# Legacy alias for completion notification
cap production slack_notify
```

### Advanced Capistrano Usage

```ruby
# Custom deployment workflow with start/end notifications
before :deploy, :notify_slack_start
after :finished, :notify_slack

# Validate configuration in deployment process
before :deploy, :validate_slack_config

# Custom task with additional data
task :deploy_with_custom_notification do
  run_locally do
    send_deployment_notification(nil, {
      custom_field: "special deployment",
      feature: "new payment system"
    })
  end
end

# Manual notification with custom notifier
task :custom_notify do
  run_locally do
    notifier = create_slack_notifier(
      webhook_url: "https://hooks.slack.com/custom/webhook"
    )
    send_deployment_notification(notifier, {
      special: "custom deployment"
    })
  end
end
```

### Automatic Data Collection

The Capistrano integration automatically collects:

- **Application**: From `:application` setting
- **Environment**: From `:stage` setting
- **Branch**: From `:branch` or git
- **User**: From CircleCI, environment, or system
- **Servers**: From Capistrano roles
- **Git Info**: Current and previous revisions
- **CircleCI Info**: Build URLs, job info, PR numbers
- **Timestamps**: Deployment start/completion times

### Legacy Compatibility

```ruby
# Old method name still works
define_slack_notification_task

# Add to deployment flow
after :finished, :notify_slack
```

## Advanced Usage

```ruby
# Custom message with full control
notifier.send_custom_message({
  text: "🎉 Special deployment completed!",
  channel: "#special-channel",
  attachments: [{
    color: "good",
    fields: [
      {title: "Environment", value: "production", short: true},
      {title: "Feature", value: "New payment system", short: true}
    ]
  }]
})
```

## Environment Variables

Set these environment variables for configuration:

### Required
- `SLACK_WEBHOOK_URL`: Your Slack webhook URL

### Optional
- `SLACK_NOTIFICATIONS_ENABLED`: "true" to enable notifications (default: true)
- `SLACK_WEBHOOK_URL_ENV_VAR`: Name of environment variable containing webhook URL
- `SLACK_CHANNEL`: Override default channel
- `SLACK_USERNAME`: Bot username
- `SLACK_EMOJI`: Bot emoji
- `SLACK_TITLE`: Custom notification title
- `SLACK_COLOR`: Attachment color

### Network Settings
- `SLACK_TIMEOUT`: HTTP timeout in seconds (default: 10)
- `SLACK_RETRY_ATTEMPTS`: Number of retry attempts (default: 3)
- `SLACK_RETRY_DELAY`: Delay between retries in seconds (default: 1)

### CircleCI Integration (auto-detected)
- `CIRCLE_USERNAME`: Deployment user
- `CIRCLE_BUILD_URL`: Build URL
- `CIRCLE_WORKFLOW_ID`: Workflow ID
- `TARGET_IPS`: Comma-separated list of target server IPs

## Atomic Features

The SlackNotifier is designed for atomic operation:
- ✅ **Independent**: Works without server selection features
- ✅ **Configurable**: YAML files or environment variables
- ✅ **Robust**: Retry logic, validation, and error handling
- ✅ **Testable**: Built-in validation and testing methods
- ✅ **Flexible**: Custom messages and deployment notifications
