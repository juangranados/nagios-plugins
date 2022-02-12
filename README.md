# Nagios/Icinga plugins

Several Nagios/Icinga Plugins written in PowerShell. All of them return Nagios permonmance data and exit code.

- [Active Directory Replication](https://github.com/juangranados/nagios-plugins/blob/master/check_adreplication.ps1): Check AD Replication in a DC Server.
- [Azure AD Connect](https://github.com/juangranados/nagios-plugins/blob/master/check_azureadconnectsync.ps1): Check Azure AD Connect status and last replication.
- [Backup Exec Jobs](https://github.com/juangranados/nagios-plugins/blob/master/check_bejobs.ps1): Check Backup Exec (2012-2017) last scheduled job status.
- [Disk Fragmentation](https://github.com/juangranados/nagios-plugins/blob/master/check_diskdefragstatus.ps1): Check disks fragmentation status and optionally defrag them if warning or critical.
- [Internet Information Server](https://github.com/juangranados/nagios-plugins/blob/master/check_iis.ps1): Check Internet Information Server Websites and AppPools and try to start (filtered) stopped ones.
- [Veeam Jobs](https://github.com/juangranados/nagios-plugins/blob/master/check_veeamjobs.ps1): Check Veeam last result of all jobs.
- [Windows Services](https://github.com/juangranados/nagios-plugins/blob/master/check_services.ps1): Check all automatic services are running and try to start stopped ones.
- [Windows Update](https://github.com/juangranados/nagios-plugins/blob/master/check_updates.ps1): Check if there are additional updates that have not been applied to a Microsoft Windows machine.
- [Windows Server Backup](https://github.com/juangranados/nagios-plugins/blob/master/check_wsb.ps1): Check Windows Server Backup last backup.
- [Windows drives fragmentation](https://github.com/juangranados/nagios-plugins/blob/master/check_diskdefragstatus.ps1): Check Windows drives fragmentation and optionally defrag them.
- [Linux disk queue](https://github.com/juangranados/nagios-plugins/blob/master/check_diskq.sh): Check Linux disk queue using iostat.
