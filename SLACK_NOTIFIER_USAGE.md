# Slack Notifier Usage

Simple deployment notifications with minimal setup using environment variables.

## Quick Setup

**1. Add to deploy.rb:**
```ruby
require "ec2_deployment_selector"
include Ec2DeploymentSelector::CapistranoIntegration

define_slack_notification_tasks
after :finished, :notify_slack
```

**2. Set environment variable:**
```bash
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
```

That's it! No config files needed.

## Configuration

### Environment Variables
```bash
# Required
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...

# Optional
SLACK_CHANNEL=#deployments
SLACK_USERNAME=Deploy Bot
SLACK_EMOJI=🚀
SLACK_TITLE=Deployment Complete!
```

### YAML File (Optional)
Create `config/slack_notifications.yml` for per-environment settings:
```yaml
production:
  channel: "#production-alerts"
  username: "Production Bot"
```

## Built-in Defaults
- Channel: `#deployments`
- Username: `Deploy Bot`
- Emoji: `🚀`
- Title: `Deployment Complete!`
- Color: `good` (green)

## Available Tasks
```bash
cap production notify_slack        # Send deployment notification
```

## Direct Usage
```ruby
notifier = Ec2DeploymentSelector::SlackNotifier.new
notifier.send_deployment_notification({
  application: "my-app",
  environment: "production",
  branch: "main"
})
```
