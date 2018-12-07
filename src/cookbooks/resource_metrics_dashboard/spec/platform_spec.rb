# frozen_string_literal: true

require 'spec_helper'

describe 'resource_metrics_dashboard::default' do
  before do
    stub_command("dpkg -l | grep '^ii' | grep grafana | grep 5.2.1").and_return(false)
  end

  context 'configures the operating system' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'has the correct platform_version' do
      expect(chef_run.node['platform_version']).to eq('16.04')
    end
  end
end
