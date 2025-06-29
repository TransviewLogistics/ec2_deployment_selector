require 'ec2_deployment_selector'

define_slack_notification_tasks

before :deploy, :validate_slack_config
after :finished, :notify_slack

task :custom_notify do
  run_locally do
    send_deployment_notification(nil, {
      feature: fetch(:feature_name, "standard"),
      custom_field: "value"
    })
  end
end
