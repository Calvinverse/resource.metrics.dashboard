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

default['grafana']['version'] = '5.2.4'
default['grafana']['file']['checksum']['deb'] = 'e4fe9335c2e933d852ceb87848d32d99af4e351ac9a484d33ad907b43c1d3945'

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

default['telegraf']['service_user'] = 'telegraf'
default['telegraf']['service_group'] = 'telegraf'
default['telegraf']['config_directory'] = '/etc/telegraf/telegraf.d'
