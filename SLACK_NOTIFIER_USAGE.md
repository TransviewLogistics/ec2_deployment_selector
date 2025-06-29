# Slack Notifier Usage

The Slack Notifier provides deployment notifications with minimal setup through environment variables and optional YAML customization.

## Quick Setup (Most Repositories)

**1. Add to deploy.rb:**
```ruby
require "ec2_deployment_selector"
include Ec2DeploymentSelector::CapistranoIntegration

define_slack_notification_tasks

# ... your deployment logic ...

namespace :deploy do
  after :finished, :notify_slack
end
```

**2. Set environment variables (in CircleCI):**
```bash
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
SLACK_CHANNEL=#deployments
```

**That's it!** No config files needed.

## Built-in Defaults

- **Channel**: `#deployments` (override with `SLACK_CHANNEL`)
- **Username**: `Deploy Bot` (override with `SLACK_USERNAME`)
- **Emoji**: `🚀`
- **Title**: `Deployment Complete!`
- **Colors**: `good` (green for success)
- **Retries**: 3 attempts with 1s delay
- **Timeout**: 10 seconds

## Environment Variable Overrides

```bash
# Required
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...

# Optional customization
SLACK_CHANNEL=#custom-deployments
SLACK_USERNAME=Custom Bot
SLACK_EMOJI=🎉
SLACK_TITLE=Custom Deployment Message
SLACK_COLOR=warning
```

## Advanced Customization (Optional)

For complex customization, create `config/slack_notifications.yml`:

```yaml
staging:
  username: "Staging Bot"
  channel: "#staging-deployments"
  emoji: "🏗️"
  title: "Staging Deployment"

production:
  username: "Production Bot"
  channel: "#production-alerts"
  emoji: "🚀"
  color: "danger"
```

## Configuration Priority

1. **Environment Variables** (highest)
2. **YAML File**
3. **Built-in Defaults** (lowest)

## Available Tasks

```bash
cap validate_slack_config  # Check configuration
cap test_slack             # Send test message
cap notify_slack           # Send deployment notification
cap notify_slack_start     # Send deployment start notification
```

## Message Content

Notifications automatically include:
- Application name and environment
- Git branch and deployment user
- Target servers and IPs
- Deployment timestamp
- CircleCI pipeline links (when available)
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

## Integration with EC2 Selector Metadata

```ruby
# Use Selector with metadata collection
selector = Ec2DeploymentSelector::Selector.new(
  access_key_id: ENV["ACCESS_KEY_ID"],
  secret_access_key: ENV["SECRET_ACCESS_KEY"],
  application_name: "my-app",
  filters: { "ENV_Type" => "production" },
  track_metadata: true  # Enable metadata collection
)

# Perform selection
selector.render_all_instances
selector.prompt_select_instances
selector.confirm_selected_instances

# Get deployment data for notifications
deployment_data = selector.deployment_data_for_notifications

# Send notification with collected server data
notifier = Ec2DeploymentSelector::SlackNotifier.new(
  webhook_url: ENV["SLACK_WEBHOOK_URL"],
  stage: "production"
)

notifier.send_deployment_notification(deployment_data)
```

### Direct Integration (Convenience Method)

```ruby
# Shorthand: send notification directly from selector
selector = Ec2DeploymentSelector::Selector.new(
  access_key_id: ENV["ACCESS_KEY_ID"],
  secret_access_key: ENV["SECRET_ACCESS_KEY"],
  application_name: "my-app",
  filters: { "ENV_Type" => "production" },
  track_metadata: true
)

selector.render_all_instances
selector.prompt_select_instances
selector.confirm_selected_instances

# Option 1: Pass notifier options
selector.send_slack_notification(
  webhook_url: ENV["SLACK_WEBHOOK_URL"],
  stage: "production"
)

# Option 2: Pass configured notifier instance
notifier = Ec2DeploymentSelector::SlackNotifier.new(
  config_file_path: "config/slack.yml",
  stage: "production"
)
selector.send_slack_notification(notifier)
```

## Usage with Configuration File
