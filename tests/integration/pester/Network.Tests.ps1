Describe 'The network' {
    Context 'on the machine' {
        It 'should have a SSH configuration' {
            '/etc/ssh/sshd_config' | Should -Exist
        }

        It 'should allow SSH' {
            $sshdConfig = Get-Content /etc/ssh/sshd_config
            $sshdConfig | Should -Not -Be $null
            ($sshdConfig | Where-Object { $_ -match '(Port)\s*(22)' }) | Should -Not -Be ''
        }
    }
}