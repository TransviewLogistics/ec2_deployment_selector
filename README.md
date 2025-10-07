# Ec2DeploymentSelector

EC2 deployment tooling and Slack notifications for Ruby applications.

## Features

- **EC2 Instance Selection**: Find and select EC2 instances for deployment
- **Slack Notifications**: Send deployment notifications with minimal setup
- **Capistrano Integration**: Automated deployment workflows

## Installation

```ruby
gem 'ec2_deployment_selector'
```

## Quick Start

### EC2 Instance Selection
```ruby
require "ec2_deployment_selector"

selector = Ec2DeploymentSelector::Selector.new(
  access_key_id: ENV["ACCESS_KEY_ID"],
  secret_access_key: ENV["SECRET_ACCESS_KEY"],
  application_name: "my-app",
  filters: { "ENV_Type" => "production" }
)

selector.render_all_instances
selector.prompt_select_instances
```

### Slack Notifications
```ruby
# In your config/deploy.rb
require "ec2_deployment_selector"

# Hook into deployment lifecycle (you control when to notify)
after 'deploy:finished', 'ec2_deployment_selector:slack:notify'
```

Set environment variable:
```bash
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
```

## Documentation

- **[Slack Notifier Usage](SLACK_NOTIFIER_USAGE.md)**: Complete notification setup guide

## Capistrano Integration

Add the gem to your Gemfile and require it in your `config/deploy.rb`:

```ruby
require 'ec2_deployment_selector'
```

See [examples/capistrano_deploy.rb](examples/capistrano_deploy.rb) for complete setup examples.

### Environment Variables

#### Required
- `ACCESS_KEY_ID` / `AWS_ACCESS_KEY_ID` - AWS access key
- `SECRET_ACCESS_KEY` / `AWS_SECRET_ACCESS_KEY` - AWS secret key

#### Optional
- `NON_INTERACTIVE=true` - Skip interactive prompts
- `TARGET_IPS=ip1,ip2` - Deploy to specific IPs only
- `SLACK_WEBHOOK_URL` - Enable Slack notifications

### Available Tasks

```bash
# Slack notifications
cap production ec2_deployment_selector:slack:notify

# Manual task invocation
invoke 'ec2_deployment_selector:slack:notify'
```

### Non-Interactive Mode

For CI/CD pipelines, auto-select all deployable instances:
```bash
NON_INTERACTIVE=true bundle exec cap production deploy
```

Deploy to specific instances by IP:
```bash
NON_INTERACTIVE=true TARGET_IPS="123.123.123.123,192.168.123.123" bundle exec cap staging deploy
```

## Instance Deployability

Instances must be "running" and not have a "Deployable" tag set to "false".

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

### Testing

Run the test suite with:

```bash
bundle exec rspec
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/ec2_deployment_selector.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
