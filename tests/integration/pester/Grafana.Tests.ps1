Describe 'The grafana application' {
    Context 'is installed' {
        It 'with binaries in /usr/sbin/grafana-server' {
            '/usr/sbin/grafana-server' | Should Exist
        }

        It 'with default configuration in /etc/grafana/grafana.ini' {
            '/etc/grafana/grafana.ini' | Should Exist
        }
    }

    Context 'has been daemonized' {
        $serviceConfigurationPath = '/usr/lib/systemd/system/grafana-server.service'
        if (-not (Test-Path $serviceConfigurationPath))
        {
            It 'has a systemd configuration' {
               $false | Should Be $true
            }
        }

        $expectedContent = @'
[Unit]
Description=Grafana instance
Documentation=http://docs.grafana.org
Wants=network-online.target
After=network-online.target
After=postgresql.service mariadb.service mysql.service

[Service]
EnvironmentFile=/etc/default/grafana-server
User=grafana
Group=grafana
Type=simple
Restart=on-failure
WorkingDirectory=/usr/share/grafana
RuntimeDirectory=grafana
RuntimeDirectoryMode=0750
ExecStart=/usr/sbin/grafana-server                                                  \
                            --config=${CONF_FILE}                                   \
                            --pidfile=${PID_FILE_DIR}/grafana-server.pid            \
                            --packaging=deb                                         \
                            cfg:default.paths.logs=${LOG_DIR}                       \
                            cfg:default.paths.data=${DATA_DIR}                      \
                            cfg:default.paths.plugins=${PLUGINS_DIR}                \
                            cfg:default.paths.provisioning=${PROVISIONING_CFG_DIR}


LimitNOFILE=10000
TimeoutStopSec=20
UMask=0027

[Install]
WantedBy=multi-user.target
'@

        # Because the grafana install adds some random spaces to the end of a line we have to trim them ... doh
        # Additionally the file doesn't end with a new line so we add one because it's not that easy to not have one
        # in our expected content bit.
        $expectedContent = $expectedContent.TrimEnd()
        $serviceFileContent = (Get-Content $serviceConfigurationPath | Foreach-Object { $_.TrimEnd() } | Out-String).TrimEnd()
        $systemctlOutput = & systemctl status grafana-server
        It 'with a systemd service' {
            $($serviceFileContent) | Should Be ($expectedContent -replace "`r", "")

            $systemctlOutput | Should Not Be $null
            $systemctlOutput.GetType().FullName | Should Be 'System.Object[]'
            $systemctlOutput.Length | Should BeGreaterThan 3
            $systemctlOutput[0] | Should Match 'grafana-server.service - Grafana instance'
        }

        It 'that is enabled' {
            $systemctlOutput[1] | Should Match 'Loaded:\sloaded\s\(.*;\senabled;.*\)'

        }

        It 'and is running' {
            $systemctlOutput[2] | Should Match 'Active:\sactive\s\(running\).*'
        }
    }

    Context 'can be contacted' {
        try
        {
            $response = Invoke-WebRequest -Uri "http://localhost:3000/dashboards/metrics/api/ping" -Headers $headers -UseBasicParsing
        }
        catch
        {
            # Because powershell sucks it throws if the response code isn't a 200 one ...
            $response = $_.Exception.Response
        }

        It 'responds to HTTP calls' {
            $response.StatusCode | Should Be 200
        }
    }
}
