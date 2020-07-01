#! /bin/bash
reset

packets=2 # number of packets sent by ping
verbose_ping=0 #show the ping result, along with the abstract

check_if_up(){
	server_check=$(ss -aolp | grep 60001 | awk '{print $ 4}' | cut -d':' -f4)
	while [[ $server_check != 60001 ]]; do
		echo -e "\e[91m[-] Server is not up, will retry to connect every 5 seconds...\e[0m"
		server_check=$(ss -aolp | grep 60001 | awk '{print $ 4}' | cut -d':' -f4)
		sleep 5
	done
	
	echo -e "\e[32m[+] Server is up and listening!\e[0m${IFS}"
	sleep 1.5
	
	routing=$(ps -ef | grep "make connect-router-cooja" | grep -v "grep" | wc -l)
	if [[ $routing -lt 1 ]]; then
		echo -e "\e[91m[-] run: \"cd /home/user/contiki-2.7/examples/ipv6/rpl-border-router/ && make connect-router-cooja\" and try again\e[0m"
		exit
	fi
	
}

check_dependencies(){
	dpkg --get-selections | grep recode &>/dev/null
	if [[ $? != 0 ]]; then
		echo -e "\e[91m[-] Dependecies check failed...\e[0m"
		echo -e "\"sudo apt-get install recode\" will solve your problem"
		exit
	else
		echo -e "\e[32m[+] Dependecies check passed\e[0m"
		sleep 1.5
	fi
}

check_dependencies
check_if_up



echo -e "\e[32m[+] Sending GET request on border router\e[0m"

while :
do
	tmp_resp1=$(curl -sg -6 http://[aaaa::212:7401:1:101])
	tmp_resp2=$(curl -sg -6 http://[aaaa::212:7401:1:101])

	cmp1=$(echo "$tmp_resp1" | sed -E 's/ [0-9]{8}s$//g')
	cmp2=$(echo "$tmp_resp2" | sed -E 's/ [0-9]{8}s$//g')

	if [[ "$cmp1" == "$cmp2" ]]; then
		resp=$tmp_resp1
		break
	fi
done

neigh=$(echo "$resp" | sed -E 's/<.+>//g; s/N.*s//g; /^[[:space:]]*$/d' | grep -v "^[^f]" | sed -E 's/^.{4}/aaaa/g')
hop=$(echo "$resp" | sed -E 's/>a/\na/g' | grep -v "^[^a]" | awk '{print $1}' | cut -d'/' -f'1')
via=$(echo "$resp" | sed -E 's/>a/\na/g' | grep -v "^[^a]" | awk '{print $2,$3}')

echo -e "\e[91m[+] Near nodes\e[0m${IFS}\e[34m$neigh\e[0m${IFS}"
echo -e "\e[91m[+] All nodes\e[0m${IFS}\e[94m$hop\e[0m${IFS}"
echo -e "\e[90m==================================================================\e[0m"


ping_(){

	for i in $1; do
		echo -e "${IFS}\e[$2m\t\t\t$i\e[0m"
		echo -e "\e[32m[+] Pinging the node"
		
		ping_result=$(ping6 -c$packets $i)
	
		if [[ $verbose_ping == 1 ]]; then
			echo "$ping_result"
		fi

		ttl=$(echo "$ping_result" | egrep "ttl" | awk '{print $6}' | sed 's/=/ ->  /g' | sort -u)
		rtt=$(echo "$ping_result" | egrep "rtt" | sed -E 's/\..{3}//g; s/.*rtt/rtt -> /g; s/ = /\n\t/g; s/\//|/g')
	
		echo -e "\e[95m$ttl\e[0m"
		echo -e "\e[95m$rtt\e[0m"
	
		echo -e "${IFS}\e[32m[+] Sending GET request\e[0m"
		get_response=$(curl -sg http://[$i])
		get_response_beautiful=$(echo "$get_response" | recode html | sed -E 's/<br>/\n/g; s/<.{,3}>//g' | grep -v "^<")
		echo -e "\e[95m$get_response_beautiful\e[0m"
	
		echo -e "\e[90m==================================================================\e[0m"
	done
}

hit=$(echo -e "$hop${IFS}$neigh" | sort -u)

if [[ ! -z "$1" ]]; then
	for (( i=1; i<=$1; i++ )); do
		ping_ "$hit" "96" "$1"
	done
else
	ping_ "$hit" "96"
fi

echo
