#!/usr/bin/perl

# Imago <imagotrigger@gmail.com>
#  AllegBot - IRC interfaces to Trac 0.12 (via. XML-RPC & Postgres) and JSON-RPCs to/from ZONE

use common::sense;
use DBI;
use AnyEvent;
use AnyEvent::IRC::Client;
use AnyEvent::JSONRPC::Lite::Server;
use RPC::XML::Client;
use String::IRC;
use POSIX qw(floor);
use Proc::Daemon;
use URI::Escape;

#setup!
my $chan = '#FreeAllegiance';
my $server = 'irc.quakenet.org';
my $name = 'AllegBot';

# Daemonize
Proc::Daemon::Init();

#IRC/JSON events
our $snow = time;
my $c = AnyEvent->condvar;
our $con = AnyEvent::IRC::Client->new( send_initial_whois => 1 );
our $srv = AnyEvent::JSONRPC::Lite::Server->new( port => 53312 );

#callbacks
my $w = AnyEvent->idle (cb => sub { doIdle(time);});
$con->reg_cb(disconnect => sub { Connect(); });
$con->reg_cb(publicmsg => sub { my (undef,$chan,$msg) = @_; doMsg($msg); }); 
$srv->reg_cb(echo => sub {my ($res_cv, @params) = @_; $res_cv->result(@params); Echo(@params); });

#RPC & DB init
our $rpc = RPC::XML::Client->new('http://trac.allegiancezone.com/rpc');
our $cli = RPC::XML::Client->new('http://trac.allegiancezone.com/ircannouncer_service');
our $dbh = DBI->connect('dbi:Pg:dbname=trac', 'tracuser', 'allegdb') or die "$!";
our $selb = $dbh->prepare(q{SELECT * FROM bitten_build WHERE id = ?}) or die $!;
our $selr = $dbh->prepare(q{SELECT * FROM revision WHERE rev = ?}) or die $!;
our $sela = $dbh->prepare(q{SELECT * FROM attachment WHERE type = 'build' AND id = ?}) or die $!;
our $sele = $dbh->prepare(q{SELECT * FROM bitten_error WHERE build = ? ORDER BY orderno DESC LIMIT 1}) or die $!;
our $sell = $dbh->prepare(q{SELECT * FROM bitten_build WHERE config = 'R6' AND status = 'S' ORDER BY id DESC LIMIT 1}) or die $!;
our $sels = $dbh->prepare(q{SELECT bitten_step.build, bitten_step.status, bitten_step.name, bitten_step.started, bitten_step.stopped FROM bitten_step, bitten_build WHERE bitten_build.id = bitten_step.build AND slave = 'zone' ORDER BY bitten_step.stopped DESC LIMIT 1;}) or die $!;
our $selrl = $dbh->prepare(q{SELECT * FROM revision ORDER BY time DESC LIMIT 1}) or die $!;
our $seltl = $dbh->prepare(q{SELECT * FROM ticket ORDER BY changetime DESC LIMIT 1}) or die $!;

#DB events (yay postgres!)
our $sent = 0; #build start/end
$dbh->do("LISTEN ticket_update");
$dbh->do("LISTEN ticket_insert");
$dbh->do("LISTEN revision_insert");
$dbh->do("LISTEN bitten_insert");

#Join the IRC channel
Connect();

#Do callbacks
$c->wait;

#Done
$selb->finish;
$selr->finish;
$sela->finish;
$sele->finish;
$sell->finish;
$sels->finish;
$selrl->finish;
$seltl->finish;
$dbh->disconnect;
exit 0;  #Quit OK

##
## Subroutines
##

#Helper to (re) join the IRC channel
sub Connect {
	$con->send_srv ("JOIN", $chan);
	$con->connect ($server, 6667, { nick => $name });
}

#Callback when no other callbacks are being called - Keeps DB cnxn alive, DBD::Pg will NOTIFY every 5 seconds (if available) - Sends chat announcment.
sub doIdle {
	my $now = shift;
	if ($now - 5 > $snow) {
		my $notify = $dbh->pg_notifies;
		if ($notify) {
			my ($name, $pid, $payload) = @$notify;
			if ($name eq 'ticket_update' || $name eq 'ticket_insert') {
				$seltl->execute() or die $!;
				my $tl = $seltl->fetchrow_hashref;
				my $status = ($name eq 'ticket_update') ? String::IRC->new('Modified')->inverse->bold : String::IRC->new('Added')->inverse->bold;
				#TODO: Make ticket update messages 'smarter' (look in ticket_change table)!
			 	$con->send_long_message ("iso-8859-1", 0, "PRIVMSG", $chan, GetTicket($tl->{id}).' '.$status);
			 	$con->send_long_message ("iso-8859-1", 0, "PRIVMSG", $chan, String::IRC->new("http://trac.allegiancezone.com/ticket/".$tl->{id})->light_blue);
			} elsif($name eq 'revision_insert') {
				$selrl->execute() or die $!;
				my $rl = $selrl->fetchrow_hashref;
				my $status = String::IRC->new('Added')->inverse->bold;
				my $rev = $rl->{rev};
				$rev =~ s/^0*//;
			 	$con->send_long_message ("iso-8859-1", 0, "PRIVMSG", $chan, GetChange($rev).' '.$status);
			 	$con->send_long_message ("iso-8859-1", 0, "PRIVMSG", $chan, String::IRC->new("http://trac.allegiancezone.com/changeset/".$rev)->light_blue);
			} elsif($name eq 'bitten_insert') {
				$sels->execute() or die $!;
				my $s = $sels->fetchrow_hashref;
				my $status = ($s->{status} eq 'S') ? String::IRC->new('Passed')->white('green')->bold : String::IRC->new('Failed')->white('red')->bold;
				my $intro = String::IRC->new('Build')->bold->underline;
				my $min = floor((($s->{stopped} - $s->{started}) / 60) + 0.5); #round up
				my $msgprog = $intro .' b'.$s->{build}.' - Step: '.$s->{name}.' '.$status." took $min min.";
				my $msgstart = $intro .' b'.$s->{build}.': In progress...';
				my $valid = (time - $s->{stopped} < 15) ? 1 : 0; # never show old messages
				if ($s->{name} eq 'Checkout' && $valid && !$sent) {
					$con->send_long_message ("iso-8859-1", 0, "PRIVMSG", $chan, $msgstart); #start
					$sent = 1;
				} elsif (($s->{status} eq 'F' || $s->{name} eq 'Done') && $valid && $sent) {
					$con->send_long_message ("iso-8859-1", 0, "PRIVMSG", $chan, GetBuild($s->{build})); #finish
					$con->send_long_message ("iso-8859-1", 0, "PRIVMSG", $chan, String::IRC->new("http://trac.allegiancezone.com/build/R6/".$s->{build})->light_blue);
					$sent = 0;
				} else {
					#$con->send_long_message ("iso-8859-1", 0, "PRIVMSG", $chan, $msgprog) if ($valid); #step
				}
			}
		}
    		$dbh->ping() or $con->send_long_message ("iso-8859-1", 0, "PRIVMSG", $chan, "It seems I've lost the connection to trac, reconnected or quit."), $dbh = DBI->connect('dbi:Pg:dbname=trac', 'trac', 'TAZ2010') or die "$!";
		$snow = $now;
	}
}

#Callback when a chat is entered into the public channel - Sends chat reply
sub doMsg { # TODO: timer! (no flood)
	my $msg = shift;
	my $str = $msg->{params}[1];
	my $tickets = "";
	#tickets via Trac RPC API Plugin
	while ($str =~ /\#(\d+)/gi) {
		$con->send_long_message ("iso-8859-1", 0, "PRIVMSG", $chan, GetTicket($1));
		$con->send_long_message ("iso-8859-1", 0, "PRIVMSG", $chan, String::IRC->new("http://trac.allegiancezone.com/ticket/$1")->light_blue);
	}
	#changesets via Trac IRCAnnouncer Plugin
	while ($str =~ /rev(\d+)/gi) {
		$con->send_long_message ("iso-8859-1", 0, "PRIVMSG", $chan, GetChange($1));
		$con->send_long_message ("iso-8859-1", 0, "PRIVMSG", $chan, String::IRC->new("http://trac.allegiancezone.com/changeset/$1")->light_blue);
	}	
	#builds via PgSQL
	while ($str =~ /b(\d+)/gi) {
		$con->send_long_message ("iso-8859-1", 0, "PRIVMSG", $chan, GetBuild($1));
		$con->send_long_message ("iso-8859-1", 0, "PRIVMSG", $chan, String::IRC->new("http://trac.allegiancezone.com/build/R6/$1")->light_blue);
		
	}	
	#latest via PgSQL
	if ($str =~ /^\!latest$/) {
		my $ret = GetLatest();
		$con->send_long_message ("iso-8859-1", 0, "PRIVMSG", $chan, $ret->{msg});
		$con->send_long_message ("iso-8859-1", 0, "PRIVMSG", $chan, String::IRC->new('http://trac.allegiancezone.com/build/R6/'.$ret->{id})->light_blue);
	}
	#search via PgSQL
	if ($str =~ /^\!search (.*)/) {
		my $q = uri_escape($1);
		$con->send_long_message ("iso-8859-1", 0, "PRIVMSG", $chan, "Pshhh, find it yourself you lazy SOB...");
		$con->send_long_message ("iso-8859-1", 0, "PRIVMSG", $chan, String::IRC->new('http://trac.allegiancezone.com/search?q='.$q)->light_blue);
	}	
}

#Helper when doMsg has a Ticket # - Formats IRC reply
sub GetTicket {
	my $tnum = shift;
	my @resp = $rpc->simple_request('ticket.get',$tnum);
	if ($resp[0] && $resp[0][0] == $tnum) {
		my $ticket = $resp[0][3];
		my $desc = $ticket->{description};
		$desc =~ s/\n+/ ** /gi;
		my $intro = String::IRC->new('Ticket')->bold->underline;
		#TODO: Color priority if >= major defect, Color grey priority if enhancment
		return $intro.' '.$ticket->{status}.' '.$ticket->{priority}.' '.$ticket->{type}." #$tnum: ".$ticket->{summary}.' By '.$ticket->{reporter}.' - '.$desc.' updated '.$ticket->{changetime};
	}	
}

#Helper when doMsg has a rev# - Formats IRC reply
sub GetChange {
	my $rev = shift;
	my $resp = $cli->simple_request('ircannouncer.getChangeset',$rev); 
	if ($resp->{rev} == $rev) {
		my $desc = $resp->{message};
		$desc =~ s/\n+/ ** /gi;
		my $intro = String::IRC->new('Revision')->bold->underline;
		return $intro.' in '.$resp->{path}.' ('.$resp->{file_count}." files) for rev$rev: By ".$resp->{author}.' - '.$desc;
	}
}

#Helper when doMsg has a b# - Formats IRC reply
sub GetBuild {
	my $bid = shift;
	$selb->execute($bid) or die $!;
	my $b = $selb->fetchrow_hashref;
	if ($bid == $b->{id}) {
		my $status = ($b->{status} eq 'S') ? String::IRC->new('Passed')->white('green')->bold : String::IRC->new('Failed')->white('red')->bold;
		my $min = floor((($b->{stopped} - $b->{started}) / 60) + 0.5); #round up
		my $rev = sprintf('%010d',$b->{rev});
		my $aid = $b->{config}.'/'.$bid;
		$selr->execute($rev) or die $!;
		my $r = $selr->fetchrow_hashref;
		$sela->execute($aid) or die $!;
		my $a = $sela->fetchrow_hashref;
		$sele->execute($bid) or die $!;
		my $e = $sele->fetchrow_hashref;
		my $intro = String::IRC->new('Build')->bold->underline;
		my $error = ($e->{build} && $b->{status} eq 'F') ? ' ** Step: '.$e->{step}.' last words were: "'.$e->{message}.'"' : '';
		my $attach = ($a->{id} && !$error) ? ' ** '. $a->{description}." - http://trac.allegiancezone.com/raw-attachment/build/$aid/".$a->{filename} : '';
		return $intro ." b$bid: By ".$r->{author}.' for rev'.$b->{rev}.' '.$status." in $min min.$attach$error";
	}
}

#Helper when doMsg has a !latest - calls GetBuild with latest green build ID
sub GetLatest {
	$sell->execute() or die $!;
	my $b = $sell->fetchrow_hashref;
	my $msg = GetBuild($b->{id});
	my %ret = (id => $b->{id}, msg => $msg);
	return \%ret;
}

#Callback when a RPC using JSON via TCP is recieved for method `echo` - Sends chat reply
sub Echo {
	my @params = @_;
	$con->send_long_message ("iso-8859-1", 0, "PRIVMSG", $chan, $params[0]);
}


__END__

-- Begin PL/PgSQL to enhance Trac database with external async. event notifications

-- Ticket Insert
CREATE FUNCTION notify_ticket_insert() RETURNS trigger AS $$
DECLARE
BEGIN
 execute 'NOTIFY ticket_insert';
 return new;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER ticket_trigger_insert AFTER insert ON ticket EXECUTE PROCEDURE notify_ticket_insert();

-- Ticket Update
CREATE FUNCTION notify_ticket_update() RETURNS trigger AS $$
DECLARE
BEGIN
 execute 'NOTIFY ticket_update';
 return new;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER ticket_trigger_update AFTER update ON ticket EXECUTE PROCEDURE notify_ticket_update();

-- Revision Insert
CREATE FUNCTION notify_revision_insert() RETURNS trigger AS $$
DECLARE
BEGIN
 execute 'NOTIFY revision_insert';
 return new;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER revision_trigger_insert AFTER insert ON revision EXECUTE PROCEDURE notify_revision_insert();

-- Build Step Insert
CREATE FUNCTION notify_bitten_insert() RETURNS trigger AS $$
DECLARE
BEGIN
 execute 'NOTIFY bitten_insert';
 return new;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER bitten_step_trigger_insert AFTER insert ON bitten_step EXECUTE PROCEDURE notify_bitten_insert();

-- End Procedures
