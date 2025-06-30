module Ec2DeploymentSelector
  require "ec2_deployment_selector/version"
  require "ec2_deployment_selector/selector"
  require "ec2_deployment_selector/slack_notifier"
end

if defined?(Capistrano)
  load File.expand_path("../ec2_deployment_selector/tasks/slack.rake", __FILE__)
end
