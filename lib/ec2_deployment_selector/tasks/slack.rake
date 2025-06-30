namespace :ec2_deployment_selector do
  namespace :slack do
    desc 'Notify about deployment completion'
    task :notify do
      # ...existing code...
      servers = []
      if respond_to?(:roles) && roles(:all).any?
        servers = roles(:all).map do |server|
          hostname = server.hostname

          server_info = {
            name: hostname,
            ip: hostname,
            public_ip: hostname,
            roles: server.roles.map(&:to_s)
          }

          # Enrich with EC2 metadata if available
          metadata = Ec2DeploymentSelector::SlackNotifier.get_ec2_metadata(hostname)
          if metadata
            server_info.merge!({
              name: metadata[:name] || hostname,
              public_ip: metadata[:public_ip] || hostname,
              private_ip: metadata[:private_ip],
              instance_type: metadata[:instance_type],
              layers: metadata[:layers],
              region: metadata[:region]
            })
          end

          server_info
        end
      end

      Ec2DeploymentSelector::SlackNotifier.new(stage: fetch(:stage)).send_deployment_notification(
        application: fetch(:application),
        branch: fetch(:branch),
        servers: servers
      )
    end
  end
end
