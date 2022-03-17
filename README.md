# Nagios/Icinga plugins

Several Nagios/Icinga Plugins written in PowerShell. Most of them return Nagios performance data too.

- [Active Directory Replication](https://github.com/juangranados/nagios-plugins/blob/master/check_adreplication.ps1): Check AD Replication in a DC Server.
- [Azure AD Connect](https://github.com/juangranados/nagios-plugins/blob/master/check_azureadconnectsync.ps1): Check Azure AD Connect status and last replication.
- [Backup Exec Jobs](https://github.com/juangranados/nagios-plugins/blob/master/check_bejobs.ps1): Check Backup Exec / Veritas (2012-2019) last scheduled job status.
- [Disk Fragmentation](https://github.com/juangranados/nagios-plugins/blob/master/check_diskdefragstatus.ps1): Check disks fragmentation status and optionally defrag them if warning or critical.
- [Check Icinga Agent](https://github.com/juangranados/nagios-plugins/blob/master/check_icingaversion.ps1) / [Install Icinga Agent](https://github.com/juangranados/nagios-plugins/blob/master/install_icinga.ps1): Check Icinga Agent version and optionally updates it.
- [Internet Information Server](https://github.com/juangranados/nagios-plugins/blob/master/check_iis.ps1): Check Internet Information Server Websites and AppPools and try to start (filtered) stopped ones.
- [Linux disk queue](https://github.com/juangranados/nagios-plugins/blob/master/check_diskq.sh): Check Linux disk queue using iostat.
- [Veeam Jobs](https://github.com/juangranados/nagios-plugins/blob/master/check_veeamjobs.ps1): Check Veeam last result of all jobs.
- [Watchguard CPU](https://github.com/juangranados/nagios-plugins/blob/master/check_wg_cpu.sh): Check Watchguard CPU.
- [Watchguard Load](https://github.com/juangranados/nagios-plugins/blob/master/check_wg_load.sh): Check Watchguard Load 1, 5 and 15.
- [Watchguard Memory](https://github.com/juangranados/nagios-plugins/blob/master/check_wg_mem.sh): Check Watchguard memory.
- [Watchguard Network](https://github.com/juangranados/nagios-plugins/blob/master/check_wg_network.sh): Check Watchguard network connections and bandwidth.
- [Watchguard Signatures](https://github.com/juangranados/nagios-plugins/blob/master/check_wg_signatures.sh): Check Gateway Antivirus Service and/or Intrusion Prevention Service last update.
- [Watchguard Tunnels](https://github.com/juangranados/nagios-plugins/blob/master/check_wg_tunnels.sh): Check if one or more of Branch Office VPN Tunnels are active on a Watchguard device.
- [Windows drives fragmentation](https://github.com/juangranados/nagios-plugins/blob/master/check_diskdefragstatus.ps1): Check Windows drives fragmentation and optionally defrag them.
- [Windows Server Backup](https://github.com/juangranados/nagios-plugins/blob/master/check_wsb.ps1): Check Windows Server Backup last backup.
- [Windows Services](https://github.com/juangranados/nagios-plugins/blob/master/check_services.ps1): Check all automatic services are running and try to start stopped ones.
- [Windows Update](https://github.com/juangranados/nagios-plugins/blob/master/check_updates.ps1): Check if there are additional updates that have not been applied to a Microsoft Windows machine.
