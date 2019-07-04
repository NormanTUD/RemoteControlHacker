#!/usr/bin/perl

use strict;
use warnings;
use autodie;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
use Term::ANSIColor;
use Time::HiRes qw/gettimeofday nanosleep/;
use Math::Cartesian::Product;
use File::Which;
use String::ShellQuote;

sub debug (@);

sub debug (@) {
	foreach (@_) {
		warn "$_\n";
	}
}

my $todo_protocol = shift @ARGV;
my $uploaded = 0;
our $initiated_protocol = '';

sub check_environment {
	debug "check_environment";
	my %needed = (
		'ino' => 'pip install ino'
	);

	foreach (keys %needed) {
		if(!which($_)) {
			die "ERROR: $_ not found. Run `sudo $needed{$_}` for installing it!";
		}
	}

	if(!-d 'lib' || !-d 'src') {
		die("ERROR: Needs to be an ino-project. Run `ino init` here!")
	}
}



check_environment();

sub dier (@);

# Protokolle:
# https://www.mikrocontroller.net/articles/IRMP

my %protocols = (
	nec => {
		start => { on => 9000, off => 4500 },
		0 => { on => 560, off => 560 },
		1 => { on => 560, off => 1690 },
		stop => { on => 560, off => 0 },
		data => "8,i,8,i"
	},
	jvc => {
		start => { on => 9000, off => 4500 },
		0 => { on => 560, off => 560 },
		1 => { on => 560, off => 1690 },
		stop => { on => 560, off => 0 },
		data => "16"
	},
	'nec16' => {
		start => { on => 9000, off => 4500 },
		0 => { on => 560, off => 560 },
		1 => { on => 560, off => 1690 },
		stop => { on => 560, off => 0 },
		data => "8,s,8",
		sync_bit => { on => 560, off => 4500 },
	},
	'nec42' => {
		start => { on => 9000, off => 4500 },
		stop => { on => 560, off => 0 },
		0 => { on => 560, off => 560 },
		1 => { on => 560, off => 1690 },
		data => "13,i,8,i"
	},
	'acp24' => {
		start => { on => 390, off => 950 },
		stop => { on => 390, off => 0 },
		0 => { on => 390, off => 950 },
		1 => { on => 390, off => 1300 },
		data => "70"
	},
	'lgair' => {
		start => { on => 9000, off => 4500 },
		stop => { on => 560, off => 0 },
		0 => { on => 560, off => 560 },
		1 => { on => 560, off => 1690 },
		data => "28"
	},
	'samsung' => {
		start => { on => 4500, off => 4500 },
		stop => { on => 550, off => 0 },
		0 => { on => 550, off => 550 },
		1 => { on => 550, off => 1650 },
		sync_bit => { on => 550, off => 4500 },
		data => "16,s,4,8,i"
	},
	'samsung32' => {
		start => { on => 4500, off => 4500 },
		stop => { on => 550, off => 0 },
		0 => { on => 550, off => 550 },
		1 => { on => 550, off => 1650 },
		data => "32"
	},
	'samsung' => { ### doppelt!
		start => { on => 4500, off => 4500 },
		stop => { on => 550, off => 0 },
		0 => { on => 550, off => 550 },
		1 => { on => 550, off => 1650 },
		data => "48"
	},
	'matsushita' => {
		start => { on => 3488, off => 3488 },
		stop => { on => 872, off => 0 },
		0 => { on => 872, off => 872 },
		1 => { on => 872, off => 2616 },
		data => "24"
	},
	'technics' => {
		 start => { on => 3488, off => 3488 },
		 stop => { on => 872, off => 0 },
		 0 => { on => 872, off => 872 },
		 1 => { on => 872, off => 2616 },
		 data => "22"
	},
	'kaseikyo' => {
		 start => { on => 3380, off => 1690 },
		 stop => { on => 423, off => 0 },
		 0 => { on => 423, off => 423 },
		 1 => { on => 423, off => 1269 },
		 data => "48"
	},
	'recs80' => {
		start => { on => 158, off => 7432},
		stop => { on => 158, off => 0 },
		0 => { on => 158, off => 4902 },
		1 => { on => 158, off => 7432 },
		data => "10"
	},
	### RECS80EXT nicht implementiert wegen 2 start-bits
	### DENON nicht implementiert wegen 0 start-bits
	### APPLE nicht implementiert wegen 11100000
	'bose' => {
		start => { on => 1060, off => 1425 },
		stop => { on => 550, off => 0 },
		0 => { on => 550, off => 437 },
		1 => { on => 550, off => 1425 },
		data => "16"
	},
	### B&O nicht implementiert wegen 4 start-bits
	### FDC nicht implementiert wegen 12x0-Bit
	'nikon' => {
		start => { on => 2200, off => 27100 },
		stop => { on => 500, off => 0 },
		0 => { on => 500, off => 1500 },
		1 => { on => 500, off => 3500 },
		data => "2"
	},
	### PANASONIC nicht implementiert wegen 010000000000010000000001 bits
	'pentax' => {
		start => { on => 2200, off => 27100 },
		stop => { on => 1000, off => 0 },
		0 => { on => 1000, off => 1000 },
		1 => { on => 1000, off => 3000 },
		data => "6"
	},
	'kathrein' => {
		start => { on => 210, off => 6218 },
		stop => { on => 210, off => 0},
		0 => { on => 210, off => 1400 },
		1 => { on => 210, off => 3000 },
		data => "11"
	},
	'lego' => {
		start => { on => 158, off => 1026 },
		stop => { on => 158, off => 0 },
		0 => { on => 158, off => 263 },
		1 => { on => 158, off => 553 },
		data => "16"
	},
	'vincent' => {
		start => { on => 2500, off => 4600 },
		stop => { on => 550, off => 0 },
		0 => { on => 550, off => 550 },
		1 => { on => 550, off => 1540 },
		data => "16,8,w"
	},
	### THOMSON nicht implementiert wegen 0 start-bits
	'telefunken' => {
		start => { on => 600, off => 1500 },
		stop => { on => 600, off => 0 },
		0 => { on => 600, off => 600 },
		1 => { on => 600, off => 1500 },
		data => "15"
	},
	'rccar' => {
		start => { on => 2000, off => 2000 },
		stop => { on => 600, off => 0 },
		0 => { on => 600, off => 900 },
		1 => { on => 600, off => 450 },
		data => "13"
	},
	'testprotokoll' => {
		start => { on => 2000, off => 2000 },
		stop => { on => 600, off => 0 },
		0 => { on => 600, off => 900 },
		1 => { on => 600, off => 450 },
		data => "4"
	},
	### RCMM nicht implementiert wegen zu vielen Frames
	### SPEAKER und die anderen nicht implementiert weil zu faul
);

my $full_data = '';
while (<DATA>) {
	$full_data .= $_;
}

main();

sub main {
	debug "main";
	foreach my $protocol_type (keys %protocols) {
		if(!$todo_protocol || $protocol_type eq $todo_protocol) {
			my $last_file = 'last_signal_'.$protocol_type.'.txt';
			my $last_signal = '';
			if(-e $last_file) {
				$last_signal = `cat $last_file`;
				chomp $last_signal;
			}

			my $continue = 1;
			if($last_signal) {
				$continue = 0;
			}

			try_signals($protocol_type, $last_file, $continue, $last_signal);
		}
	}
}

sub try_signals {
	debug "try_signal";
	my $type = shift;
	my $last_file = shift;
	my $this_protocol = $protocols{$type};
	my $continue = shift;
	my $last_signal = shift;

	if(!exists($protocols{$type})) {
		die("Unknown protocol!");
	}
	my @signals = generate_signals($this_protocol);
	my $i = 1;
	my $done = 0;
	my $time_sum = 0;
	foreach my $signal (@signals) {
		if(!$continue) {
			if($last_signal) {
				if($signal eq $last_signal) {
					$continue = 1;
				} else {
					$continue = 0;
				}
			} else {
				$continue = 1;
			}
		}

		if($continue) {
			my $start = gettimeofday();
			print "\n\n";
			print color("green")."$i of ".scalar(@signals)." (".sprintf("%.4f", ($i / scalar(@signals)) * 100)."%)".color("reset")."\n";
			if($time_sum) {
				my $avg_time = $time_sum / $done;
				my $time_left = convert_time($avg_time * (scalar(@signals) - $i));
				print color("blue")."Time left: $time_left, avg. time: ".$avg_time.color("reset")."\n";
			}
			print color("red").$signal.color("reset")."\n";

			try_signal($signal, $protocols{$type}, $type, $last_file);

			my $end = gettimeofday();
			$time_sum += ($end - $start);
			$done++;
		}
		$i++;
	}
}

sub pushdata {
	debug "pushdata";
	my $string = shift;

return;
### TODO
	my $command = "echo ".my_shell_quote($string."sleep\nblink\n")." > /dev/ttyACM4";
	system($command);
}

sub my_shell_quote {
	debug "my_shell_quote";
	my $string = shift;

	return "\"$string\"";
}

sub create_program {
	debug "create_program";
	open my $fh, '>', 'src/sketch.ino';
	print $fh $full_data;
	close $fh;
}

sub try_signal {
	debug "try_signal";
	my $signal = shift;
	my $this_protocol = shift;
	my $this_protocol_name = shift;
	my $last_file = shift;
	my $converted = convert_binary_to_code($signal);
	create_program();
	if(!$uploaded) {
		my $overdone = 0;
		while (!upload()) {
			warn "Upload didn't work, try it again!\n";
			exit(1) if $overdone == 2;
			$overdone++;
		}
		$uploaded = 1;
	}

	initiate_protocol($this_protocol_name, $this_protocol);

	my $sleep_time = 0;
	$sleep_time += $this_protocol->{start}->{on} + $this_protocol->{start}->{off};
	$sleep_time += $this_protocol->{stop}->{on} + $this_protocol->{stop}->{off};

	foreach my $item (split(//, $converted)) {
		my $name = $item;
		#if($item =~ m#^0|1$#) {
		if($item =~ m#^s$#) {
			$name = 'sync_bit';
		}
		if(exists($this_protocol->{$name}->{on})) {
			$sleep_time += $this_protocol->{$name}->{on} + $this_protocol->{$name}->{off};
		}

	}

	$sleep_time += (500 + 500) * 10;

	$sleep_time *= 5;
	$sleep_time = int($sleep_time);

	pushdata($converted);

	nanosleep $sleep_time; ### TODO!!! Richtige Zeit berechnen * 2!!!
	
	open my $fh, '>', $last_file;
	print $fh $signal;
	close $fh;
}

sub initiate_protocol {
	debug "initiate_protocol";
	my $this_protocol_name = shift;
	my $this_protocol = shift;

	return undef if $initiated_protocol eq $this_protocol_name;

	my $one_on = $this_protocol->{1}->{on};
	my $one_off = $this_protocol->{1}->{off};

	my $zero_on = $this_protocol->{0}->{on};
	my $zero_off = $this_protocol->{0}->{off};

	my $stop_on = $this_protocol->{stop}->{on};
	my $stop_off = $this_protocol->{stop}->{off};

	my $start_on = $this_protocol->{start}->{on};
	my $start_off = $this_protocol->{start}->{off};

	my $sync_bit_on = $this_protocol->{sync_bit}->{on} // 0;
	my $sync_bit_off = $this_protocol->{sync_bit}->{off} // 0;

	my $string = '';
	$string .= "ONEON=$one_on\n";
	$string .= "ONEOFF=$one_off\n";

	$string .= "ZEROON=$zero_on\n";
	$string .= "ZEROOFF=$zero_off\n";

	$string .= "STOPON=$stop_on\n";
	$string .= "STOPOFF=$stop_off\n";

	$string .= "STARTON=$start_on\n";
	$string .= "STARTOFF=$start_off\n";

	$string .= "SYNCON=$sync_bit_on\n";
	$string .= "SYNCOFF=$sync_bit_off\n";

	$initiated_protocol = $this_protocol_name;

	pushdata($string);
}

sub convert_binary_to_code {
	debug "convert_binary_to_code";
	my $binary = shift;

	my $string = '';
	foreach my $this (split(//, $binary)) {
		$string .= $this."\n";
	}

	return $string;
}

sub generate_signals {
	debug "generate_signals";
	# wtf, hier passiert magie
	my $this_protocol = shift;

	my $data = $this_protocol->{data};

	my @data_signal = split(/,/, $data);

	my @signals_to_chose_from = ();

	my $i = 0;
	my $j = 0;
	my $contains_sync_bit = 0;
	my $sync_bit_position = undef;
	foreach my $this_data_structure (@data_signal) { #8, i, 8, i
		my $number_of_data = $this_data_structure;
		if($this_data_structure eq 'i') {
			$number_of_data = $data_signal[$i - 1];
		}
		my @this_data = generate_bits($number_of_data);
		if($this_data_structure eq 'i') {
			$signals_to_chose_from[$#signals_to_chose_from] = { %{$signals_to_chose_from[$#signals_to_chose_from]}, 1 => { max_element => $#this_data, type => 'i', data => [map { invert($_) } @this_data ] }};
		} elsif ($this_data_structure eq 'w') {
			$signals_to_chose_from[$#signals_to_chose_from] = { %{$signals_to_chose_from[$#signals_to_chose_from]}, 1 => { max_element => $#this_data, type => 'w', data => [@this_data] }};
		} elsif ($this_data_structure eq 's') {
			$contains_sync_bit = 1;
			$sync_bit_position = $i;
		} else {
			push @signals_to_chose_from, { 0 => { part => $j, max_element => $#this_data, type => $number_of_data, data => [@this_data] }};
			$j++;
		}
		$i++;
	}

	my %parts = ();
	foreach my $this (@signals_to_chose_from) {
		my $max_element = $this->{0}->{max_element};
		my $part = $this->{0}->{part};
		foreach (0 .. $max_element) {
			my $string = '';
			$string .= $this->{0}->{data}->[$_];
			if(exists($this->{1})) {
				$string .= $this->{1}->{data}->[$_];
			}
			push @{$parts{$part}}, $string;
		}
	}

	my @test = ();
	foreach (sort { $a <=> $b } keys %parts) {
		push @test, $parts{$_};
	}

	my @cartesian = ();
	cartesian { push @cartesian, join('', @_) } @test;

	if($contains_sync_bit) {
		my @edited = ();
		my $before = 0;

		my $start_in_string = 0;
		foreach my $k (0 .. $sync_bit_position - 1) {
			$start_in_string += $data_signal[$k];
		}

		foreach my $string (@cartesian) {
			my $char = 's';
			my $insert_pos = $start_in_string;
			my $length = 0;

			substr $string, $insert_pos, $length, $char;
			push @edited, $string;
		}
		@cartesian = @edited;
	}

	return @cartesian;
}

sub upload {
	debug "upload";
	my $ret_value = system("ino build && ino upload");
	if($ret_value) {
		return 0;
	} else {
		return 1;
	}
}

sub generate_bits {
	debug "generate_bits";
	my $n = shift;
	if($n =~ m#^\d+$#) {
		my @bits = ();
		for (0..2 ** $n - 1) {
			push @bits, substr(unpack("B*", pack("N", $_)), -$n);
		}
		return @bits;
	} elsif ($n eq 's') { # sync-bit
		return 'y';
	}
}

sub invert {
	debug "invert";
	my $z = shift;
	$z =~ s#0#a#g;
	$z =~ s#1#0#g;
	$z =~ s#a#1#g;

	return $z;
}

sub dier (@) {
	if($#_ == 1) {
		warn length($_[0])."\n";
	}
	die Dumper @_;
}

sub convert_time {
	debug "convert_time";
	my $time = shift;
	my $days = int($time / 86400);
	$time -= ($days * 86400);
	my $hours = int($time / 3600);
	$time -= ($hours * 3600);
	my $minutes = int($time / 60);
	my $seconds = $time % 60;

	$days = $days < 1 ? '' : $days .'d ';
	$hours = $hours < 1 ? '' : $hours .'h ';
	$minutes = $minutes < 1 ? '' : $minutes . 'm ';
	$time = $days . $hours . $minutes . $seconds . 's';
	return $time;
}

__DATA__
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
