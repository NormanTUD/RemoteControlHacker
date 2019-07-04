#include <Arduino.h>
#include <string.h>

using namespace std;

int led = 13; // Fuers Blinken wenn er mit dem Senden eines Signales fertig ist
int output_lamp = 10; // Auf dem Stecker ist die LED

int start_signal_on = 0;
int start_signal_off = 0;

int one_on = 0;
int one_off = 0;

int zero_on = 0;
int zero_off = 0;

int stop_on = 0;
int stop_off = 0;

int sync_bit_on = 0;
int sync_bit_off = 0;

void sp (String data) {
	Serial.print(data);
	Serial.print("\n");
	delay(1000);
}

void setup() {
	Serial.begin(115200);
	Serial.setTimeout(50);
	pinMode(output_lamp, OUTPUT);
	pinMode(led, OUTPUT);
}

void blink () {
	digitalWrite(led, HIGH);
	delay(500);
	digitalWrite(led, LOW);
	delay(500);
}

void handleSerial () {
	String receivedChars = serialEvent();
	sp("handleSerial");
	sp("receivedChars: >" + receivedChars + "<");
	if(receivedChars.length() >= 1) {
		int done_something = 0;
		if(receivedChars == "0") {
			sp("Zero");
			zero();
			done_something = 1;
		} else if(receivedChars == "1") {
			sp("One");
			one();
			done_something = 1;
		} else if(receivedChars == "s") { // stop
			stopsignal();
			done_something = 1;
		} else if(receivedChars == "b") { // begin
			start();
			done_something = 1;
		} else if(receivedChars == "y") { // sync
			sync_bit();
			done_something = 1;
		} else if(receivedChars == "blink") { // sync
			sp("Blinking now!");
			blink();
			done_something = 1;
		} else if(receivedChars == "sleep") { // sync
			delay(1000);
			done_something = 1;
		} else if(startsWith(receivedChars, "STARTON=")) {
			start_signal_on = toInt(receivedChars.substring(strlen("STARTON=")));
			done_something = 1;
		} else if(startsWith(receivedChars, "STARTOFF=")) {
			start_signal_off = toInt(receivedChars.substring(strlen("STARTOFF=")));
			done_something = 1;
		} else if(startsWith(receivedChars, "ONEON=")) {
			one_on = toInt(receivedChars.substring(strlen("ONEON=")));
			done_something = 1;
		} else if(startsWith(receivedChars, "ONEOFF=")) {
			one_off = toInt(receivedChars.substring(strlen("ONEOFF=")));
			done_something = 1;
		} else if(startsWith(receivedChars, "ZEROON=")) {
			zero_on = toInt(receivedChars.substring(strlen("ZEROON=")));
			done_something = 1;
		} else if(startsWith(receivedChars, "ZEROOFF=")) {
			zero_off = toInt(receivedChars.substring(strlen("ZEROOFF=")));
			done_something = 1;
		} else if(startsWith(receivedChars, "STOPON=")) {
			stop_on = toInt(receivedChars.substring(strlen("STOPON=")));
			done_something = 1;
		} else if(startsWith(receivedChars, "STOPOFF=")) {
			stop_off = toInt(receivedChars.substring(strlen("STOPOFF=")));
			done_something = 1;
		} else if(startsWith(receivedChars, "SYNCON=")) {
			sync_bit_on = toInt(receivedChars.substring(strlen("SYNCON=")));
			done_something = 1;
		} else if(startsWith(receivedChars, "SYNCOFF=")) {
			sync_bit_off = toInt(receivedChars.substring(strlen("SYNCOFF=")));
			done_something = 1;
		} else {
			sp("WRONG COMMAND! >>>");
			sp(receivedChars);
			sp("<<<");
		}

		if(done_something) {
			sp("Finished command");
		}
	} else {
		sp("Done nothing");
	}
	mydelay(50);
}

void loop () {
	handleSerial();
}

void stopsignal () {
	send_signal(stop_on, stop_off); 
}

void zero () {
	send_signal(zero_on, zero_off); 
}

void one () {
	send_signal(one_on, one_off); 
}

void start () {
	send_signal(start_signal_on, start_signal_off);
}

void sync_bit () {
	// Nicht in jedem Protokoll noetig
	if(sync_bit_on == 0 && sync_bit_off == 0) {
		return;
	}

	send_signal(sync_bit_on, sync_bit_off);
}

void send_signal (int on, int off) {
	digitalWrite(output_lamp, HIGH);
	mydelay(on);
	digitalWrite(output_lamp, LOW);
	mydelay(off);
}

void mydelay (int microseconds) {
	delayMicroseconds(microseconds); 
}

String serialEvent() {
	bool stringComplete;
	String inputString;
	while (!Serial.available()) {
		//int wait = 50;
		//sp("Nothing available. Waiting " + String(wait) + "ms");
		//delay(wait);
	}
	while (Serial.available()) {
		char inChar = (char)Serial.read();
		if (inChar == '\n') {
			if(inputString.length() >= 1) {
				stringComplete = true;
				sp("DETECTED: >" + inputString + "<");
				return inputString;
			} else {
				inputString = "";
			}
		} else {
			inputString += inChar;
		}
	}
}

bool startsWith (String text, String match) {
	return text.startsWith(match);
}

int toInt(String str) {
	return str.toInt();
}
