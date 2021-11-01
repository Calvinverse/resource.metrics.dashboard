BeforeAll {
    $expectedContent = @'
[Service]
ExecStart = /opt/consul/1.9.5/consul agent -config-file=/etc/consul/consul.json -config-dir=/etc/consul/conf.d
ExecReload = /bin/kill -HUP $MAINPID
RestartSec = 5
Restart = always
WorkingDirectory = /var/lib/consul
User = consul
Environment = "GOMAXPROCS=2" "PATH=/usr/local/bin:/usr/bin:/bin"
KillSignal = TERM

[Unit]
Description = consul
Wants = network.target
After = network.target
StartLimitIntervalSec = 0

[Install]
WantedBy = multi-user.target

'@
    $serviceConfigurationPath = '/etc/systemd/system/consul.service'
    $serviceFileContent = Get-Content $serviceConfigurationPath | Out-String
    $systemctlOutput = & systemctl status consul
}

Describe 'The consul application' {
    Context 'is installed' {
        It 'with binaries in /usr/local/bin' {
            '/usr/local/bin/consul' | Should -Exist
        }

        It 'with default configuration in /etc/consul/consul.json' {
            '/etc/consul/consul.json' | Should -Exist
        }

        It 'with environment configuration in /etc/consul/conf.d' {
            '/etc/consul/conf.d/bootstrap.json' | Should -not -Exist

            '/etc/consul/conf.d/location.json' | Should -Exist
            '/etc/consul/conf.d/metrics.json' | Should -Exist
            '/etc/consul/conf.d/region.json' | Should -Exist
            '/etc/consul/conf.d/secrets.json' | Should -Exist
        }
    }

    Context 'has been daemonized' {

        It 'has a systemd configuration' {
            $serviceConfigurationPath | Should -Exist
        }

        It 'with a systemd service' {
            $serviceFileContent | Should -Be ($expectedContent -replace "`r", "")

            $systemctlOutput | Should -Not -Be $null
            $systemctlOutput.GetType().FullName | Should -Be 'System.Object[]'
            $systemctlOutput.Length | Should -BeGreaterThan 3
            $systemctlOutput[0] | Should -Match 'consul.service - consul'
        }

        It 'that is enabled' {
            $systemctlOutput[1] | Should -Match 'Loaded:\sloaded\s\(.*;\senabled;.*\)'

        }

        It 'and is running' {
            $systemctlOutput[2] | Should -Match 'Active:\sactive\s\(running\).*'
        }
    }

    Context 'can be contacted' {
        It 'responds to HTTP calls' {
            $response = Invoke-WebRequest -Uri http://localhost:8500/v1/agent/self -UseBasicParsing
            $agentInformation = ConvertFrom-Json $response.Content
            $response.StatusCode | Should -Be 200
            $agentInformation | Should -Not -Be $null
        }

        It 'is not a server instance' {
            $response = Invoke-WebRequest -Uri http://localhost:8500/v1/agent/self -UseBasicParsing
            $agentInformation = ConvertFrom-Json $response.Content
            $agentInformation.Config.Server | Should -Be $false
        }
    }
}
