module Ec2DeploymentSelector
  require "ec2_deployment_selector/version"
  require "ec2_deployment_selector/selector"
  require "ec2_deployment_selector/slack_notifier"
  
  # Optional Capistrano integration - only loads if Capistrano is present
  begin
    require "ec2_deployment_selector/capistrano_integration"
  rescue LoadError
    # Capistrano not available, skip integration
  end
end
