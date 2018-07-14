# frozen_string_literal: true

#
# CONSULTEMPLATE
#

default['consul_template']['config_path'] = '/etc/consul-template.d/conf'
default['consul_template']['template_path'] = '/etc/consul-template.d/templates'

#
# FIREWALL
#

# Allow communication on the loopback address (127.0.0.1 and ::1)
default['firewall']['allow_loopback'] = true

# Do not allow MOSH connections
default['firewall']['allow_mosh'] = false

# Do not allow WinRM (which wouldn't work on Linux anyway, but close the ports just to be sure)
default['firewall']['allow_winrm'] = false

# No communication via IPv6 at all
default['firewall']['ipv6_enabled'] = false

#
# INFLUXDB
#

default['grafana']['version'] = '5.2.1'
default['grafana']['file']['checksum']['deb'] = '97722140d58365c80e8bfff091e07b84cd0f7f3de9b6601fd062cdf49660c4f3'

default['grafana']['webserver'] = '' # don't install the webserver

default['grafana']['port']['http'] = 3000
default['grafana']['proxy_path'] = 'dashboards/metrics'

default['grafana']['provisioning_dir'] = '/etc/grafana/provisioning'
default['grafana']['dashboards_dir'] = '/etc/grafana/dashboards'

default['grafana']['consul_template']['ini'] = 'grafana_custom_ini.ctmpl'
default['grafana']['consul_template']['ldap'] = 'grafana_ldap.ctmpl'
default['grafana']['consul_template']['provisioning_datasources_script'] = 'grafana_datasources.ctmpl'
default['grafana']['consul_template']['provisioning_dashboards_script'] = 'grafana_dashboards.ctmpl'

default['grafana']['telegraf']['consul_template_inputs_file'] = 'telegraf_grafana_inputs.ctmpl'

#
# TELEGRAF
#

default['telegraf']['config_directory'] = '/etc/telegraf/telegraf.d'
