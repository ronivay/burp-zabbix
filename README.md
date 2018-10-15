# Burp zabbix monitoring

This repository consists of scripts, configs and template for automatically discovering burp clients and querying latest backup timestamp. Tested with Burp v2 (v1 doesn't support remote monitoring interface) and Zabbix 4.0

#### BURP

Burp is an open source backup and restore software for Unix and Windows clients. It consists of a separate server and client.

https://burp.grke.org/

#### Zabbix

Zabbix is an open source monitoring solution

https://www.zabbix.com/

#### Why

BURP has it's own monitoring interface and built-in email notifications for successful/failed backups. BURP works in a way that the client will initiate the actual backup and server is deciding if it's time to do so. There might be cases where scheduling this backup from client side is not working, or someone forgot to add it. There is no option from the server side to alarm about this sort of behaviour, so i created these simple tools to help me monitor such situations with zabbix, which i already use for other monitoring. I'm sharing these if anyone else might find it useful.

Please submit an issue or pull request if you think anything could be done better or if things are not working as they should.

#### Installation

This won't be a complete step-by-step installation from BURP side and i assume you are already somewhat familiar with it. Basically you need to add a new client which has restore_client permissions set at the server. This restore_client is the server where your zabbix-agent is running and where you are doing monitoring from.

Check https://burp.grke.org/docs/monitor.html

- Start up by cloning this repository to your zabbix directory
```
git clone https://github.com/ronivay/burp-zabbix /etc/zabbix/burp-zabbix
```
- Edit you zabbix agent configuration and add
```
Include=/etc/zabbix/burp-zabbix/burp.conf
```
- Restart zabbix-agent

- Add sudo permissions for zabbix-agent to run burp.sh script
```
visudo

add line:
zabbix ALL=(ALL)  NOPASSWD: /etc/zabbix/burp-zabbix/burp.sh
```
Zabbix agent part is now done, we can move to our zabbix-server

* Download the `burp-monitoring.xml` file from this repository to your local machine and open your zabbix-server WebUI. 

* Navigate to `configure` -> `templates` -> `import`

* Choose the .xml file and hit import

Now we should have a new template called `Template burp backup` which we can add to our hosts.

Template has some some default values which are defined as MACRO.

`{$BACKUP_OLDER_THAN}` is set to 129600seconds which equals to 1days 12hours. Triggers support context macro, so you can defined different macros for different clients if you wish. In that case add a new macro to your host as follows:

`{$BACKUP_OLDER_THAN:burp-client-name}` and set a value that you like.

Missing backup trigger is defined so that if value for client is -126671 (-1day,11hours,11seconds, this is what the burp.sh will return if backup doesn't exist) for 129600 (1 and a half days) straight it triggers the alarm.

#### Tips

burp.sh will create a new burp_list.txt every 1hour. You have an option to switch variable CRON from `false` to `true` in the beginning of the script. This disables the list creation completely (unless it's missing). In that case add a new cronjob:

```
*/15 * * * * /etc/zabbix/burp-zabbix/burp.sh cron
```



