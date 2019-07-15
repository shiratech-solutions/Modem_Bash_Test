#!/bin/bash
phone_number="+972545535041"
test_message="This is a test message from your mezzanine" 
MODEM="/dev/tty96B0"
apn="\"sphone.pelephone.net.il\""
username="\"pcl@3g\""
password="\"rl\""
pingto="\"8.8.8.8\""


function get_response
{
        local ECHO
        cat <&5 >$TMP &
        echo "$1" >&5
        wait $!
        
		sleep 1
	
        exec 6<$TMP
        read ECHO <&6
        if [ "$ECHO" != "$1" ]
        then
                exec 6<&-
                return 1
        fi

        read ECHO <&6
        read RESPONSE <&6
        exec 6<&-
        return 0
}

function get_ping_response
{
        local ECHO
        cat <&5 >$TMP &
        echo "$1" >&5
        wait $!
        
		sleep 5
	
        exec 6<$TMP
        read ECHO <&6
        if [ "$ECHO" != "$1" ]
        then
                exec 6<&-
                return 1
        fi

        read ECHO <&6
        read RESPONSE <&6
        exec 6<&-
        return 0
}


function check_network
{
	get_response "AT" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ !($res == *"OK"*) ]]; then
		echo "check_network: AT failed"
		return	
	fi

	# Network registration status (has to contain ",1" - registered
	get_response "AT+CREG?" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ $res == *"Bad response"* || !($res == *",1"*) ]]; then
		echo "check_network: AT+CREG failed"
		echo "ERROR: Network registration failed."		
		return	
	fi
	
	# Signal quality report
	get_response "AT+CSQ" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ $res == *"Bad response"* ]]; then
		echo "check_network: AT+CSQ failed"
		return	
	fi

	#Query and report signal strength
	get_response "AT+QCSQ" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ $res == *"Bad response"* || $res == *"NOSERVICE"* ]]; then
		echo "check_network: AT+QCSQ failed"
		return	
	fi

	#Query network information
	get_response "AT+QNWINFO" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ $res == *"Bad response"* || $res == *"No Service   "* ]]; then
		echo "check_network: AT+QNWINFO failed"
		return	
	fi

	#Display the name of registered network
	get_response "AT+QSPN" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ $res == *"Bad response"* ]]; then
		echo "check_network: AT+QSPN failed"
		return	
	fi
	
	return 0
}

function check_sim
{
	get_response "AT" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ !($res == *"OK"*) ]]; then
		echo "check_sim: AT failed"
		return	
	fi

	#Check the SIM card insertion status (removed/inserted/unknown)
	get_response "AT+QSIMSTAT?" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ $res == *"Bad response"* || !($res == *"0,1"*) ]]; then
		echo "check_sim: AT+QSIMSTAT failed"
		return	
	fi

	#check SIM card number - just to verify that it is present and recognized by the modem
	get_response "AT+QCCID" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ !($res == *"OK"*) ]]; then
		echo "check_sim: AT+QCCID failed"
		return	
	fi
	
	# SIM card initialization status: 3 is actually 2 + 1
	# 1 - CPIN ready
	# 2 - SMS initialization completed 
	get_response "AT+QINISTAT" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP	
	res=""	
	res+=$(cat $TMP)
	if [[ $res == *"Bad response"* || !($res == *"3"*) ]]; then
		echo "check_sim: AT+QINISTAT failed"
		return 
	fi	
		
	return 0
}

function send_sms
{
	get_response "AT" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ !($res == *"OK"*) ]]; then
		echo "send_sms: AT failed"
		return	
	fi
	
	#Configure the output port of URC
	get_response "AT+QURCCFG=\"urcport\",\"uart1\"" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ $res == *"Bad response"* || $res == *"ERROR"* || !($res == *"OK"*)]]; then
		echo "send_sms: AT+QURCCFG failed"
		return 
	fi

	#SMS event reporting configuration
	get_response "AT+CNMI=1,2" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP	
	res=""	
	res+=$(cat $TMP)
	if [[ $res == *"Bad response"* || $res == *"ERROR"* || !($res == *"OK"*)]]; then
		echo "send_sms: AT+CNMI failed"
		return 
	fi	

	#Set text mode
	get_response "AT+CMGF=1" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ $res == *"Bad response"* || $res == *"ERROR"* || !($res == *"OK"*)]]; then
		echo "send_sms: AT+CMGF failed"
		return 
	fi
	
	#send sms
	get_response "AT+CMGS=\"$phone_number\""    	|| echo "Bad response"

	echo -ne "$test_message" > $MODEM
	echo -ne '\x1a' > $MODEM

	sleep 2

	res=""	
	res+=$(cat $TMP)
	
	if [[ $res == *"Bad response"* || $res == *"ERROR"* ]]; then
		echo "send_sms: Some error occurred at AT+CMGS"
		return 
	fi
	
 	return 0
}

function check_ping
{
	get_response "AT"
	
	sleep 5
	
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ !($res == *"OK"*) ]]; then
		echo "check_ping: AT failed"
		return	
	fi
	
	#connect to operator
	get_response "AT+QICSGP=1,1,$apn,$username,$password,1" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ !($res == *"OK"*) ]]; then
		echo "check_ping: AT+QICSGP failed"
		return	
	fi
	
	#activate context 1
	get_response "AT+QIACT=1" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ $res == *"ERROR"* ]]; then
		echo "Reactivating context"
		# recovery from "ERROR" response - deactivate pdp context, then retry
		get_response "AT+QIDEACT=1" || echo "Bad response"
		echo "Response was '${RESPONSE}'"       ;       cat $TMP
		res=""	
		res+=$(cat $TMP)
		if [[ !($res == *"OK"*) ]]; then
			echo "check_ping: AT+QIDEACT failed"
			return
		fi
		
		get_response "AT+QIACT=1" || echo "Bad response"
		echo "Response was '${RESPONSE}'"       ;       cat $TMP
		res=""	
		res+=$(cat $TMP)
		if [[ $res == *"ERROR"* ]]; then
			echo "check_ping: AT+QIACT failed"
			return
		fi
	fi
	
	# Perform the actual ping
	get_ping_response "AT+QPING=1,$pingto" || echo "Bad response"
	res=""	
	
	res+=$(cat $TMP)
	if [[ !($res == *"OK"*) ]]; then
		echo "check_ping: AT+QPING failed"
		return	
	fi
	
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	
	return 0
}


TMP="./response"

# Clear out old response
: > $TMP

# Set modem with timeout of 5/10 a second
stty -F "$MODEM" 115200 -echo igncr -icanon onlcr ixon min 0 time 5

# Open modem on FD 5
exec 5<>"$MODEM"

get_response "AT" || echo "Bad response"
echo "Response was '${RESPONSE}'"       ;       cat $TMP

echo

check_sim

check_network

send_sms

check_ping

echo "bye bye"

exec 5<&-
