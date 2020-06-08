#!/bin/bash

CRON=false
# if monitoring from burp server locally, this prevent's new clients to trigger unwanted "no backup" trigger
#CLIENTDIR="/etc/burp/clientconfdir"

# create new list of clients/backups if doesn't exist/is empty. might cause zabbix to timeout since querying burp can take a while.
if [ ! -s /etc/zabbix/burp_list.txt ]; then
        burp -a S | grep -v "burp status" | sed 's/^ *//' > /etc/zabbix/burp_list.txt
fi

burp_list=$(cat /etc/zabbix/burp_list.txt)

function BurpCreateList {

# create new list every 1hours, not every time this script runs. querying burp takes a while, so maybe move this task as cronjob if causing issues or incorrect data.
if [ $(find /etc/zabbix -type f -name "burp_list.txt" -mmin +60) ] && [ ! -f /etc/zabbix/burp_list.lock ]; then
	touch /etc/zabbix/burp_list.lock
	burp -a S | grep -v "burp status" | sed 's/^ *//' > /etc/zabbix/burp_list.tmp && \
	rm -f /etc/zabbix/burp_list.lock || { rm -f /etc/zabbix/burp_list.lock ; exit 1; }
	mv -f /etc/zabbix/burp_list.tmp /etc/zabbix/burp_list.txt
fi
}

function BurpDiscover {

IFS=$'\n' read -r -d '' -a burp_clients <<< "$(echo "$burp_list" | awk '{print $1}')"

echo -e "{\n"
echo -e "\"data\":[\n"

for burp_client in "${burp_clients[@]}"; do
	# don't discover clients created less than 24hours ago
	if [[ $CLIENTDIR ]]; then
		if [[ $(find $CLIENTDIR -mindepth 1 -maxdepth 1 -ctime +1 -name "$burp_client") ]]; then
			RESULT+=$(echo -e "\n{\n\"{#BURPCLIENT}\": \"$burp_client\"\n},")
		fi
	else
		RESULT+=$(echo -e "\n{\n\"{#BURPCLIENT}\": \"$burp_client\"\n},")
	fi
done

JSON=$(echo "$RESULT" | sed '$s/,$//')

echo "$JSON"
echo "]}"

}

function BurpClientCheck {

client="$1"

# if latest backup status is null/empty print negative number and exit
if [[ $(echo "$burp_list" | awk -v c="^$client$" '$1 ~ c' | awk '{print $5}') == "never" ]] || [[ $(echo "$burp_list" | awk -v c="^$client$" '$1 ~ c' | awk '{print $5}') == "" ]]; then
	echo "0"
	exit
fi

# else proceed with finding out the exact timestamp
backup_data=$(echo "$burp_list" | awk -v c="^$client$" '$1 ~ c' | awk '{print $6,$7}')

backup_time=$(date -d "$backup_data" +"%s")
current_time=$(date +"%s")
echo "$(( $current_time - $backup_time ))"

}

case "$1" in

	discover)
	BurpDiscover
	# execute create list afterwards and leave to background as this might timeout zabbix check
	if [ "$CRON" == "false" ]; then
		BurpCreateList &
	fi
	exit 0;
	;;
	check)
	BurpClientCheck $2
	 # execute create list afterwards and leave to background as this might timeout zabbix check
	if [ "$CRON" == "false" ]; then
	 	BurpCreateList &
	fi
	exit 0
	;;
	cron)
	BurpCreateList
	;;
	*)
	exit 0
	;;
esac 
