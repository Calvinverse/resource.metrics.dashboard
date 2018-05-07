# frozen_string_literal: true

#
# Cookbook Name:: resource_metrics_dashboard
# Recipe:: default
#
# Copyright 2018, P. van der Velde
#

# Always make sure that apt is up to date
apt_update 'update' do
  action :update
end

#
# Include the local recipes
#

include_recipe 'resource_metrics_dashboard::firewall'

include_recipe 'resource_metrics_dashboard::meta'
include_recipe 'resource_metrics_dashboard::provisioning'

include_recipe 'resource_metrics_dashboard::grafana'
