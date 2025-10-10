# CKAN Harvester Cron Jobs
# Force bash as the shell
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Run harvester every 15 seconds (4 times per minute)
# Cron doesn't support seconds, so we use sleep to run multiple times per minute
* * * * * /bin/bash /srv/app/harvest_run_wrapper.sh >> /var/log/ckan/harvester_run.log 2>&1
* * * * * sleep 15; /bin/bash /srv/app/harvest_run_wrapper.sh >> /var/log/ckan/harvester_run.log 2>&1
* * * * * sleep 30; /bin/bash /srv/app/harvest_run_wrapper.sh >> /var/log/ckan/harvester_run.log 2>&1
* * * * * sleep 45; /bin/bash /srv/app/harvest_run_wrapper.sh >> /var/log/ckan/harvester_run.log 2>&1

# Clean harvest logs daily at 5 AM
0 5 * * * /bin/bash /srv/app/harvest_cleanup_wrapper.sh >> /var/log/ckan/harvester_cleanup.log 2>&1
