#!/bin/bash
phone_number="+972545535042"
#phone_number="+972545261611"

test_message="This is a test message from BG96" 
MODEM="/dev/tty96B0"
apn="\"sphone.pelephone,net.il\""
username="\"pcl@3g\""
password="\"rl\""
pingto="\"8.8.8.8\""


function get_response
{
        local ECHO
        # cat will read the response, then die on timeout
        cat <&5 >$TMP &
        echo "$1" >&5
        # wait for cat to die
        wait $!

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
	echo "DEBUG: check_network eneterd"

	get_response "AT" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ !($res == *"OK"*) ]]; then
		return	
	fi

	# Network registration status (has to contain ",1" - registered
	get_response "AT+CREG?" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ $res == *"Bad response"* || !($res == *",1"*) ]]; then
		echo "ERROR: Network registration failed."		
		return	
	fi
	
	# Signal quality report
	get_response "AT+CSQ" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ $res == *"Bad response"* ]]; then
		return	
	fi

	#Query and report signal strength
	get_response "AT+QCSQ" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ $res == *"Bad response"* || $res == *"NOSERVICE"* ]]; then
		return	
	fi

	#Query network information
	get_response "AT+QNWINFO" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ $res == *"Bad response"* || $res == *"No Service   "* ]]; then
		return	
	fi

	#Display the name of registered network
	get_response "AT+QSPN" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ $res == *"Bad response"* ]]; then
		return	
	fi
	
	return 0
}

function check_sim
{
	#check sim id - make sure sim is present and recognized by the modem
	echo "DEBUG: check_sim entered" 	
	
	get_response "AT" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ !($res == *"OK"*) ]]; then
		return	
	fi

	#Check the SIM card insertion status (removed/inserted/unknown)
	get_response "AT+QSIMSTAT?" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ $res == *"Bad response"* || !($res == *"0,1"*) ]]; then
		return	
	fi

	#check SIM card number - just to verify that it is present and recognized by the modem
	get_response "AT+QCCID" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ !($res == *"OK"*) ]]; then
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
		return 
	fi	
		
	return 0
}

function send_sms
{
	echo "DEBUG: send_sms entered"
	
	get_response "AT" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ !($res == *"OK"*) ]]; then
		return	
	fi

	get_response "AT+QURCCFG=\"urcport\",\"uart1\"" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ $res == *"Bad response"* || $res == *"ERROR"* || !($res == *"OK"*)]]; then
		return 
	fi

	#SMS event reporting configuration
	get_response "AT+CNMI=1,2" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP	
	res=""	
	res+=$(cat $TMP)
	if [[ $res == *"Bad response"* || $res == *"ERROR"* || !($res == *"OK"*)]]; then
		return 
	fi	

	#Set text mode
	get_response "AT+CMGF=1" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ $res == *"Bad response"* || $res == *"ERROR"* || !($res == *"OK"*)]]; then
		return 
	fi
	
	#send sms
	get_response "AT+CMGS=\"$phone_number\""    	|| echo "Bad response"

	echo -ne "$test_message" > $MODEM
	echo -ne '\x1a' > $MODEM

	res=""	
	res+=$(cat $TMP)
	if [[ $res == *"Bad response"* || $res == *"ERROR"* || !($res == *"OK"*)]]; then
		return 
	fi
	
 	return 0
}

function check_ping
{
	echo "DEBUG: just_ping entered"
	
	get_response "AT" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ !($res == *"OK"*) ]]; then
		return	
	fi
	
	#connect to rami levi operator
	#get_response "AT+QICSGP=1,1,\"sphone.pelephone,net.il\",\"pcl@3g\",\"rl\",1" || echo "Bad response"
	get_response "AT+QICSGP=1,1,$apn,$username,$password,1" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ !($res == *"OK"*) ]]; then
		return	
	fi
	
	get_response "AT+QIACT=1" || echo "Bad response"
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ $res == *"ERROR"* ]]; then
		# recover from "ERROR" response - deactivate pdp context
		get_response "AT+QIDEACT=1" || echo "Bad response"
		echo "Response was '${RESPONSE}'"       ;       cat $TMP
		res=""	
		res+=$(cat $TMP)
		if [[ !($res == *"OK"*) ]]; then
			return
		fi
	fi
	
	# Perform the actual ping
	get_response "AT+QPING=1,$pingto" || echo "Bad response"
	sleep 1
	echo "Response was '${RESPONSE}'"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ !($res == *"OK"*) ]]; then
		return	
	fi
	
	sleep 5
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
