require 'spec_helper'

RSpec.describe Ec2DeploymentSelector::SlackNotifier do
  describe '#initialize' do
    it 'loads the module successfully' do
      expect { described_class.new(stage: "test") }.not_to raise_error
    end

    it 'accepts stage and webhook_url parameters' do
      notifier = described_class.new(
        stage: "production",
        webhook_url: "https://hooks.slack.com/test"
      )

      expect(notifier).to be_an_instance_of(described_class)
    end
  end

  describe '#send_deployment_notification' do
    let(:notifier) { described_class.new(stage: "test") }

    context 'without webhook URL' do
      before do
        ENV.delete("SLACK_WEBHOOK_URL")
      end

      it 'fails gracefully when webhook URL is missing' do
        result = notifier.send_deployment_notification({
          application: "test-app",
          branch: "main",
          user: "test-user"
        })

        expect(result).to be false
      end
    end

    context 'with valid webhook URL' do
      let(:notifier_with_webhook) do
        described_class.new(
          stage: "test",
          webhook_url: "https://hooks.slack.com/services/test/webhook/url"
        )
      end

      it 'accepts deployment data with modern Ruby syntax' do
        deployment_data = {
          application: "test-app",
          branch: "main",
          user: "test-user",
          revision: "abc12345",
          timestamp: Time.now.strftime("%Y-%m-%d %H:%M:%S UTC"),
          servers: [{ name: "server1", public_ip: "10.0.1.1", instance_type: "t3.medium" }]
        }

        # Should not raise error during message building
        expect { notifier_with_webhook.send_deployment_notification(deployment_data) }.not_to raise_error
      end
    end
  end

  describe 'message building' do
    let(:notifier) do
      described_class.new(
        stage: "production",
        webhook_url: "https://hooks.slack.com/test"
      )
    end

    it 'builds message with revision field' do
      deployment_data = {
        application: "test-app",
        revision: "abc12345",
        user: "test-user"
      }

      message = notifier.send(:build_message, deployment_data)

      expect(message).to be_a(Hash)
      expect(message[:text]).to include("🚀")
      expect(message[:attachments]).to be_an(Array)

      fields = message[:attachments].first[:fields]
      revision_field = fields.find { |f| f[:title] == "Revision" }

      expect(revision_field).not_to be_nil
      expect(revision_field[:value]).to eq("abc12345")
    end

    it 'includes server metadata in formatted output' do
      deployment_data = {
        servers: [
          {
            name: "test-server",
            public_ip: "1.2.3.4",
            instance_type: "t3.medium",
            region: "us-east-1"
          }
        ]
      }

      message = notifier.send(:build_message, deployment_data)
      fields = message[:attachments].first[:fields]
      servers_field = fields.find { |f| f[:title] == "Target Servers" }

      expect(servers_field).not_to be_nil
      expect(servers_field[:value]).to include("test-server")
      expect(servers_field[:value]).to include("1.2.3.4")
      expect(servers_field[:value]).to include("t3.medium")
      expect(servers_field[:value]).to include("us-east-1")
    end
  end

  describe 'configuration handling' do
    it 'uses environment variables for configuration' do
      ENV["SLACK_CHANNEL"] = "#test-channel"
      ENV["SLACK_USERNAME"] = "Test Bot"

      notifier = described_class.new(stage: "test")
      message = notifier.send(:build_message, { application: "test" })

      expect(message[:username]).to eq("Test Bot")
      expect(message[:channel]).to eq("#test-channel")

      # Cleanup
      ENV.delete("SLACK_CHANNEL")
      ENV.delete("SLACK_USERNAME")
    end

    it 'loads configuration from YAML if provided' do
      # This would test YAML configuration loading
      # For now, just ensure it doesn't break without a config file
      expect { described_class.new(config_file_path: "nonexistent.yml", stage: "test") }.not_to raise_error
    end
  end
end
