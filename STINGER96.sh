#!/bin/bash
delay=0.5

#Configure to send a custom SMS message to a desired phone number 
phone_number="+972545573903"
test_message="This is a test message from STINGER96"
idx=0
#UART tty dev (STINGER96)
MODEM="/dev/ttySTM2"

#APN Settings - mobile operator specific
apn="\"sphone.pelephone.net.il\""
username="\"pcl@3g\""
password="\"rl\""

#The URL to ping.
pingto="\"8.8.8.8\""

#Send an AT Command to Bg96 module
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

#gpio commands according to:
#https://www.96boards.org/documentation/consumer/guides/gpio.md.html
function bg96_reset
{
	#Init - Reset BG96 pins (PWRKEY and RESET to 0)
	gpioset gpiochip2 4=0
	gpioset gpiochip2 2=0
	sleep 1

#BG96_PWRKEY set, wait and reset
	gpioset gpiochip2 4=1
	sleep 0.2
	gpioset gpiochip2 4=0

	#BG96_RESET set, wait and reset
	gpioset gpiochip2 2=0
	sleep 0.5
	gpioset gpiochip2 2=1
	sleep 0.5
	gpioset gpiochip2 2=0
	sleep 0.5
	gpioset gpiochip7 7=1
	sleep 0.5
	sleep 7
}

#Check the SIM card status
function check_sim_status
{
	#Check the SIM card insertion status (removed/inserted/unknown)
	get_response "AT+QSIMSTAT?"
	echo "Response: "       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ !($res == *"OK"*) || !($res == *"0,1"*) ]]; then
		echo "check_sim: AT+QSIMSTAT failed"
		return	
	fi

	#check SIM card number - just to verify that it is present and recognized by the modem
	get_response "AT+QCCID"
	echo "Response: "       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ !($res == *"OK"*) ]]; then
		echo "check_sim: AT+QCCID failed"
		return	
	fi
	
	# SIM card initialization status: 3 is actually 2 + 1
	# 1 - CPIN ready
	# 2 - SMS initialization completed 
	get_response "AT+QINISTAT"
	echo "Response: "       ;       cat $TMP	
	res=""	
	res+=$(cat $TMP)
	if [[ !($res == *"OK"*) || !($res == *"3"*) ]]; then
		echo "check_sim: AT+QINISTAT failed"
		return 
	fi	
		
	return 0
}

#Check the network status
function check_network_status
{
	# Network registration status (has to contain ",1" - registered
	get_response "AT+CREG?"
	echo "Response was: "       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ !($res == *",1"*) ]]; then
		echo "check_network: AT+CREG failed"
		echo "ERROR: Network registration failed."		
		return	
	fi
	
	# Signal quality report
	get_response "AT+CSQ"
	echo "Response:"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ !($res == *"OK"*) ]]; then
		echo "check_network: AT+CSQ failed"
		return	
	fi

	#Query and report signal strength
	get_response "AT+QCSQ"
	echo "Response: "       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ !($res == *"OK"*) || $res == *"NOSERVICE"* ]]; then
		echo "check_network: AT+QCSQ failed"
		return	
	fi

	#Query network information
	get_response "AT+QNWINFO"
	echo "Response: "       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ !($res == *"OK"*) || $res == *"No Service   "* ]]; then
		echo "check_network: AT+QNWINFO failed"
		return	
	fi

	#Display the name of registered network
	get_response "AT+QSPN"
	echo "Response: "       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ !($res == *"OK"*) ]]; then
		echo "check_network: AT+QSPN failed"
		return	
	fi
	
	return 0
}

#Send an SMS message
function send_sms
{	
	#Configure the output port of URC
	get_response "AT+QURCCFG=\"urcport\",\"uart1\""
	echo "Response: "       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ $res == *"ERROR"* || !($res == *"OK"*)]]; then
		echo "send_sms: AT+QURCCFG failed"
		return 
	fi

	#SMS event reporting configuration
	get_response "AT+CNMI=1,2"
	echo "Response: "       ;       cat $TMP	
	res=""	
	res+=$(cat $TMP)
	if [[ $res == *"ERROR"* || !($res == *"OK"*)]]; then
		echo "send_sms: AT+CNMI failed"
		return 
	fi	

	#Set text mode
	get_response "AT+CMGF=1"
	echo "Response: "       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ $res == *"ERROR"* || !($res == *"OK"*)]]; then
		echo "send_sms: AT+CMGF failed"
		return 
	fi
	
	#send sms
	get_response "AT+CMGS=\"$phone_number\""
	((idx++))
	echo -ne "$test_message:$idx" > $MODEM
	echo -ne '\x1a' > $MODEM

	sleep 2

	res=""	
	res+=$(cat $TMP)
	
	if [[ $res == *"ERROR"* ]]; then
		echo "send_sms: Some error occurred at AT+CMGS"
		return 
	fi
	
 	return 0
}

#Ping a URL
function do_ping
{
	sleep 5
	#connect to operator
	get_response "AT+QICSGP=1,1,$apn,$username,$password,1"
	echo "Response:"       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ !($res == *"OK"*) ]]; then
		echo "check_ping: AT+QICSGP failed"
		return	
	fi
	
	#activate context 1
	get_response "AT+QIACT=1"
	echo "Response: "       ;       cat $TMP
	res=""	
	res+=$(cat $TMP)
	if [[ $res == *"ERROR"* ]]; then
		echo "Reactivating context"
		# recovery from "ERROR" response - deactivate pdp context, then retry
		get_response "AT+QIDEACT=1"
		echo "Response:"       ;       cat $TMP
		res=""	
		res+=$(cat $TMP)
		if [[ !($res == *"OK"*) ]]; then
			echo "check_ping: AT+QIDEACT failed"
			return
		fi
		
		get_response "AT+QIACT=1"
		echo "Response:"       ;       cat $TMP
		res=""	
		res+=$(cat $TMP)
		if [[ $res == *"ERROR"* ]]; then
			echo "check_ping: AT+QIACT failed"
			return
		fi
	fi
	
	# Perform the actual ping
	get_ping_response "AT+QPING=1,$pingto"
	res=""		
	res+=$(cat $TMP)
	if [[ !($res == *"OK"*) ]]; then
		echo "check_ping: AT+QPING failed"
		return
	fi
	
	echo "Response:"       ;       cat $TMP	
	return 0
}

TMP="./response"

# Clear out old response
: > $TMP

# Set modem with timeout of 5/10 a second
stty -F "$MODEM" 115200 -echo igncr -icanon onlcr ixon min 0 time 5

# Open modem on FD 5
exec 5<>"$MODEM"

bg96_reset

get_response "AT"
echo "Response:"       ;       cat $TMP
get_response "ATE"
echo "Response:"       ;       cat $TMP
get_response "ATI"
echo "Response:"       ;       cat $TMP

check_sim_status
check_network_status
while true
do
    send_sms
    sleep 5
done


echo "bye bye"

exec 5<&-
