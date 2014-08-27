rem #Imago <imagotrigger@gmail.com> Helper script (this is bitten's deployment step)

perl C:\makelist.pl
perl C:\makemotd.pl %1 %2
perl C:\makecfg.pl
perl C:\deploy.pl
perl C:\upgrade.pl