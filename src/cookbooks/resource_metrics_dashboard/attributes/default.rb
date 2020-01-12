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

default['grafana']['version'] = '6.5.2'
default['grafana']['file']['checksum']['deb'] = 'af6592f379bd4b91b202f4845c31e79e0faeff1b4b1f12cbbb720a8980f2edd7'

default['grafana']['service_user'] = 'grafana'
default['grafana']['service_group'] = 'grafana'

default['grafana']['path']['config'] = '/etc/grafana'

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
