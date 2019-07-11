This test verifies the connectivity of the mezzanine by sending an SMS message, and by performing a ping.

The test includes 3 main stages:
1) Verifying the presence and status of the SIM card.
2) Verifying Network registration and signal quality.
3) Perorming a ping.
4) Sending a test SMS.

Before running the test, edit the variables at the beginning of the test file:

Ping test variables:
	- apn, username, password: Enter your operator apn details.
	- pingto: The url which you wish to ping.
SMS test variables:
	- phone_number: The phone number where the test message should be sent to.
	- test_message: Enter your custom test message.
	- MODEM: Enter the serial device which represents the modem. This info is machine specific, for example, on Dragonboard410 the corresponding serial port is tty96B0.
	
How to run the test:

1) Copy the file to your Linux machine.
2) Grant execution permissions to the test file:
	- Open your terminal.
	- Navigate to the location containing the test file.
	- Type: 'chmod 777 bg96test.sh'
3) Run the test by typing './bg96test.sh'
4) Wait a few seconds for the SMS to be delivered.
5) Check the terminal output for the ping results.
6) The test prints all of the AT commands responses back to the terminal. Any errors encountered will be printed as well.

Please refer to the Quectel BG96 AT commands manual:
	- https://www.quectel.com/UploadImage/Downlad/Quectel_BG96_AT_Commands_Manual_V2.1.pdf